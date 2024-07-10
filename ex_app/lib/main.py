"""Windmill as an ExApp"""

import asyncio
import base64
import contextlib
import json
import os
import random
import string
import typing
from base64 import b64decode
from contextlib import asynccontextmanager
from pathlib import Path
from time import sleep

import httpx
from fastapi import BackgroundTasks, Depends, FastAPI, Request, responses, status
from nc_py_api import NextcloudApp
from nc_py_api.ex_app import LogLvl, nc_app, persistent_storage, run_app
from nc_py_api.ex_app.integration_fastapi import fetch_models_task
from starlette.responses import FileResponse, Response

# os.environ["NEXTCLOUD_URL"] = "http://nextcloud.local/index.php"
# os.environ["APP_HOST"] = "0.0.0.0"
# os.environ["APP_ID"] = "windmill_app"
# os.environ["APP_SECRET"] = "12345"
# os.environ["APP_PORT"] = "23000"

DEFAULT_USER_NAME = "admin@windmill.dev"
USERS_STORAGE_PATH = Path(persistent_storage()).joinpath("windmill_users_config.json")
USERS_STORAGE = {}
print("[DEBUG]: USERS_STORAGE_PATH=", str(USERS_STORAGE_PATH), flush=True)
if USERS_STORAGE_PATH.exists():
    with open(USERS_STORAGE_PATH, encoding="utf-8") as __f:
        USERS_STORAGE.update(json.load(__f))


def add_user_to_storage(user_name: str, password: str, token: str = "") -> None:
    USERS_STORAGE[user_name] = {"password": password, "token": token}
    with open(USERS_STORAGE_PATH, "w", encoding="utf-8") as f:
        json.dump(USERS_STORAGE, f, indent=4)


async def create_user(user_name: str) -> str:
    password = generate_random_string()
    async with httpx.AsyncClient() as client:
        r = await client.request(
            method="POST",
            url="http://127.0.0.1:8000/api/users/create",
            json={
                "email": f"{user_name}@windmill.dev",
                "password": password,
                "super_admin": True,
                "name": user_name,
            },
            cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
        )
        r = await client.post(
            url="http://127.0.0.1:8000/api/auth/login",
            json={"email": f"{user_name}@windmill.dev", "password": password},
        )
        add_user_to_storage(user_name, password, r.text)
    return r.text


async def login_user(user_name: str, password: str) -> str:
    async with httpx.AsyncClient() as client:
        r = await client.post(
            url="http://127.0.0.1:8000/api/auth/login",
            json={"email": f"{user_name}@windmill.dev", "password": password},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"login_user: {r.text}")
        return r.text


async def check_token(token: str) -> bool:
    async with httpx.AsyncClient() as client:
        r = await client.get("http://127.0.0.1:8000/api/users/whoami", cookies={"token": token})
        return bool(r.status_code < 400)


async def provision_user(request: Request) -> None:
    if "token" in request.cookies:
        print(f"DEBUG: TOKEN IS PRESENT: {request.cookies['token']}", flush=True)
        if (await check_token(request.cookies["token"])) is True:
            return
        print("DEBUG: TOKEN IS INVALID", flush=True)

    user_name = get_windmill_username_from_request(request)
    if user_name in USERS_STORAGE:
        zzz = USERS_STORAGE[user_name]["token"]
        aaa = await check_token(zzz)
        if not USERS_STORAGE[user_name]["token"] or aaa is False:
            user_password = USERS_STORAGE[user_name]["password"]
            add_user_to_storage(user_name, user_password, await login_user(user_name, user_password))
    else:
        await create_user(user_name)
    request.cookies["token"] = USERS_STORAGE[user_name]["token"]
    print(f"DEBUG: ADDING TOKEN({request.cookies['token']}) to request", flush=True)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    _t = asyncio.create_task(start_background_webhooks_syncing())  # noqa
    yield


APP = FastAPI(lifespan=lifespan)
# APP.add_middleware(AppAPIAuthMiddleware)  # set global AppAPI authentication middleware


def get_windmill_username_from_request(request: Request) -> str:
    auth_aa = b64decode(request.headers.get("AUTHORIZATION-APP-API", "")).decode("UTF-8")
    try:
        username, _ = auth_aa.split(":", maxsplit=1)
    except ValueError:
        username = ""
    if not username:
        raise RuntimeError("`username` should be always set.")
    return "wapp_" + username


def enabled_handler(enabled: bool, nc: NextcloudApp) -> str:
    print(f"enabled={enabled}")
    if enabled:
        nc.log(LogLvl.WARNING, f"Hello from {nc.app_cfg.app_name} :)")
        nc.ui.resources.set_script("top_menu", "windmill_app", "ex_app/js/windmill_app-main")
        nc.ui.top_menu.register("windmill_app", "Workflow Engine", "ex_app/img/app.svg")
    else:
        nc.log(LogLvl.WARNING, f"Bye bye from {nc.app_cfg.app_name} :(")
        nc.ui.resources.delete_script("top_menu", "windmill_app", "ex_app/js/windmill_app-main")
        nc.ui.top_menu.unregister("windmill_app")
    return ""


@APP.get("/heartbeat")
async def heartbeat_callback():
    return responses.JSONResponse(content={"status": "ok"})


@APP.post("/init")
async def init_callback(b_tasks: BackgroundTasks, nc: typing.Annotated[NextcloudApp, Depends(nc_app)]):
    b_tasks.add_task(fetch_models_task, nc, {}, 0)
    return responses.JSONResponse(content={})


@APP.put("/enabled")
def enabled_callback(enabled: bool, nc: typing.Annotated[NextcloudApp, Depends(nc_app)]):
    return responses.JSONResponse(content={"error": enabled_handler(enabled, nc)})


@APP.api_route("/api/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH", "TRACE"])
async def proxy_backend_requests(request: Request, path: str):
    # print(f"proxy_BACKEND_requests: {path} - {request.method}\nCookies: {request.cookies}", flush=True)
    await provision_user(request)
    async with httpx.AsyncClient() as client:
        url = f"http://127.0.0.1:8000/api/{path}"
        headers = {key: value for key, value in request.headers.items() if key.lower() not in ("host", "cookie")}
        if request.method == "GET":
            response = await client.get(
                url,
                params=request.query_params,
                cookies=request.cookies,
                headers=headers,
            )
        else:
            response = await client.request(
                method=request.method,
                url=url,
                params=request.query_params,
                headers=headers,
                cookies=request.cookies,
                content=await request.body(),
            )
        # print(
        #     f"proxy_BACKEND_requests: method={request.method}, path={path}, status={response.status_code}", flush=True
        # )
        response_header = dict(response.headers)
        response_header.pop("transfer-encoding", None)
        return Response(content=response.content, status_code=response.status_code, headers=response_header)


@APP.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH", "TRACE"])
async def proxy_frontend_requests(request: Request, path: str):
    print(f"proxy_FRONTEND_requests: {path} - {request.method}\nCookies: {request.cookies}", flush=True)
    await provision_user(request)
    if path == "index.php/apps/app_api/proxy/windmill_app/":
        path = path.replace("index.php/apps/app_api/proxy/windmill_app/", "")
    if path.startswith("ex_app"):
        file_server_path = Path("../../" + path)
    elif not path or path == "user/login":
        # file_server_path = Path("../../windmill_tmp/frontend/build/200.html")
        file_server_path = Path("/iframe/200.html")
    else:
        # file_server_path = Path("../../windmill_tmp/frontend/build/").joinpath(path)
        file_server_path = Path("/iframe/").joinpath(path)
    if not file_server_path.exists():
        return Response(status_code=status.HTTP_404_NOT_FOUND)
    response = FileResponse(str(file_server_path))
    response.headers["content-security-policy"] = "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;"
    print("proxy_FRONTEND_requests: <OK> Returning: ", str(file_server_path), flush=True)
    return response


def initialize_windmill() -> None:
    if not USERS_STORAGE_PATH.exists():
        while True:  # Let's wait until Windmill opens the port.
            with contextlib.suppress(httpx.ReadError, httpx.ConnectError, httpx.RemoteProtocolError):
                r = httpx.get("http://127.0.0.1:8000/api/users/whoami")
                if r.status_code in (401, 403):
                    break
        r = httpx.post(
            url="http://127.0.0.1:8000/api/auth/login", json={"email": "admin@windmill.dev", "password": "changeme"}
        )
        if r.status_code >= 400:
            raise RuntimeError(f"initialize_windmill: can not login with default credentials, {r.text}")
        default_token = r.text
        new_default_password = generate_random_string()
        r = httpx.post(
            url="http://127.0.0.1:8000/api/users/setpassword",
            json={"password": new_default_password},
            cookies={"token": default_token},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"initialize_windmill: can not change default credentials password, {r.text}")
        add_user_to_storage(DEFAULT_USER_NAME, new_default_password, default_token)
        r = httpx.post(
            url="http://127.0.0.1:8000/api/workspaces/create",
            json={"id": "nextcloud", "name": "nextcloud"},
            cookies={"token": default_token},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"initialize_windmill: can not create default workspace, {r.text}")
        r = httpx.post(
            url="http://127.0.0.1:8000/api/w/nextcloud/workspaces/edit_auto_invite",
            json={"operator": False, "invite_all": True, "auto_add": True},
            cookies={"token": default_token},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"initialize_windmill: can not create default workspace, {r.text}")


def generate_random_string(length=10):
    letters = string.ascii_letters + string.digits  # You can include other characters if needed
    return "".join(random.choice(letters) for i in range(length))  # noqa


async def start_background_webhooks_syncing():
    await asyncio.to_thread(webhooks_syncing)


def webhooks_syncing():
    workspace = "nextcloud"

    while True:
        nc = NextcloudApp()
        if nc.enabled_state:
            print("Running workflow sync")
            token = USERS_STORAGE[DEFAULT_USER_NAME]["token"]
            flow_paths = get_flow_paths(workspace, token)
            print(flow_paths)
            expected_listeners = get_expected_listeners(workspace, token, flow_paths)
            print(json.dumps(expected_listeners, indent=4), flush=True)
            registered_listeners = get_registered_listeners()
            # for expected_listener in expected_listeners:
            #     registered_listeners_for_uri = get_registered_listeners_for_uri(expected_listener['webhook'], registered_listeners)
            #     for event in expected_listener['events']:
            #         listener = next(filter(lambda listener: listener['event'] == event, registered_listeners_for_uri), None)
            #         if listener is not None:
            #             json.dumps(listener)
            #             if json.dumps(listener['eventFilter']) != json.dumps(expected_listener['filters']):
            #                 update_listener(listener, expected_listener['filters'], token)
            #         else:
            #             register_listener(event, expected_listener['filters'], expected_listener['webhook'], token)
            # registered_listeners = get_registered_listeners()
            # for registered_listener in registered_listeners:
            #     if registered_listener['appId'] == os.environ["APP_ID"]:
            #         if next(filter(lambda expected_listener: registered_listener['uri'] == expected_listener['webhook'] and registered_listener['event'] in expected_listener['events'], expected_listeners), None) is None:
            #             await delete_listener(registered_listener)
        sleep(5 * 60)


def get_flow_paths(workspace: str, token: str) -> list[str]:
    method = "GET"
    path = f"/w/{workspace}/flows/list"
    print(f"sync_API_request: {path} - {method}", flush=True)
    flow_paths = []
    with httpx.Client() as client:
        url = f"http://127.0.0.1:8000/api{path}"
        headers = {"Authorization": f"Bearer {token}"}
        # print(f"proxy_BACKEND_requests: method={request.method}, path={path}, status={response.status_code}")
        response = client.request(
            method=method,
            url=url,
            params={"per_page": 100},
            headers=headers,
        )
        print(
            f"sync_API_request: method={method}, path={path}, status={response.status_code}",
            flush=True,
        )
        try:
            response_data = json.loads(response.content)
            for flow in response_data:
                flow_paths.append(flow["path"])
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON: {e}")
    return flow_paths


def get_expected_listeners(workspace: str, token: str, flow_paths: list[str]) -> list[dict]:
    flows = []
    for flow_path in flow_paths:
        with httpx.Client() as client:
            method = "GET"
            path = f"/w/{workspace}/flows/get/{flow_path}"
            url = f"http://127.0.0.1:8000/api/{path}"
            headers = {"Authorization": f"Bearer {token}"}
            print(f"sync_API_request: {path} - {method}", flush=True)
            response = client.request(
                method=method,
                url=url,
                params={"per_page": 100},
                headers=headers,
            )
            print(
                f"sync_API_request: method={method}, path={path}, status={response.status_code}",
                flush=True,
            )
            try:
                response_data = json.loads(response.content)
            except json.JSONDecodeError as e:
                print(f"Error parsing JSON: {e}")
                return []
            first_module = response_data["value"]["modules"][0]
            if (
                first_module["summary"] == "CORE:LISTEN_TO_EVENT"
                and first_module["value"]["input_transforms"]["events"]["type"] == "static"
                and first_module["value"]["input_transforms"]["filters"]["type"] == "static"
            ):
                webhook = f"http://127.0.0.1:8000/api/w/{workspace}/jobs/run/f/{flow_path}"
                # webhook = f"https://app.windmill.dev/api/w/{workspace}/jobs/run/f/{flow_path}"
                input_transforms = first_module["value"]["input_transforms"]
                flows.append(
                    {
                        "webhook": webhook,
                        "filters": input_transforms["filters"]["value"],
                        # Remove backslashes from the beginning to yield canonical reference
                        "events": [
                            event[1:] if event.startswith("\\") else event
                            for event in input_transforms["events"]["value"]
                        ],
                    }
                )
    return flows


def get_registered_listeners_for_uri(webhook: str, registered_listeners: list) -> list:
    return [listener for listener in registered_listeners if listener["uri"] == webhook]


# async def register_listener(event, filter, webhook, token):
#     async with httpx.AsyncClient() as client:
#         method = 'POST'
#         path = '/ocs/v2.php/apps/webhook_listeners/api/v1/webhooks'
#         url = os.environ["NEXTCLOUD_URL"]+path
#         userid = os.environ["NEXTCLOUD_USERID"]
#         secret = os.environ["NEXTCLOUD_SECRET"]
#
#         headers = {
#
#             'AUTHORIZATION-APP-API': base64.b64encode(bytes(f"{userid}:{secret}", 'utf-8')).decode('utf-8'),
#             'OCS-APIREQUEST': 'true',
#             'EX-APP-VERSION': 'v1.0.0',
#             'EX-APP-ID': os.environ['APP_ID'],
#             'AA-VERSION': 'v2.3.0'
#         }
#         auth_data = {
#             'Authorization': f"Bearer {token}"
#         }
#         print(f"sync_API_nextcloud_request: {url} - {method}", flush=True)
#         print(json.dumps(filter, indent=4), flush=True)
#         response = await client.request(
#             method=method,
#             url=url,
#             json={'httpMethod': 'POST', 'uri': webhook, 'event': event, 'eventFilter': filter, 'authMethod': 'header', 'authData': auth_data},
#             headers=headers,
#             params={'format': 'json'}
#         )
#         print(
#             f"sync_API_nextcloud_request: method={method}, path={path}, status={response.status_code}",
#             flush=True
#         )
#         try:
#             response_data = json.loads(response.content)
#         except json.JSONDecodeError as e:
#             print(f"Error parsing JSON: {e}")
#             return
#         print(json.dumps(response_data, indent=4), flush=True)
#         return response_data['ocs']['data']


# async def update_listener(registered_listener, filter, token):
#     async with httpx.AsyncClient() as client:
#         method = 'POST'
#         path = f"/ocs/v2.php/apps/webhook_listeners/api/v1/webhooks/{registered_listener['id']}"
#         url = os.environ["NEXTCLOUD_URL"] + path
#         userid = os.environ["NEXTCLOUD_USERID"]
#         secret = os.environ["NEXTCLOUD_SECRET"]
#
#         headers = {
#             'AUTHORIZATION-APP-API': base64.b64encode(bytes(f"{userid}:{secret}", 'utf-8')).decode('utf-8'),
#             'OCS-APIREQUEST': 'true',
#             'EX-APP-VERSION': 'v1.0.0',
#             'EX-APP-ID': os.environ['APP_ID'],
#             'AA-VERSION': 'v2.3.0'
#         }
#         auth_data = {
#             'Authorization': f"Bearer {token}"
#         }
#         print(f"sync_API_nextcloud_request: {url} - {method}", flush=True)
#         print(json.dumps(filter, indent=4), flush=True)
#         response = await client.request(
#             method=method,
#             url=url,
#             json={'httpMethod': 'POST', 'uri': registered_listener['uri'], 'event': registered_listener['event'], 'eventFilter': filter, 'authMethod': 'header',
#                   'authData': auth_data},
#             headers=headers,
#             params={'format': 'json'}
#         )
#         print(
#             f"sync_API_nextcloud_request: method={method}, path={path}, status={response.status_code}",
#             flush=True
#         )
#         try:
#             response_data = json.loads(response.content)
#         except json.JSONDecodeError as e:
#             print(f"Error parsing JSON: {e}")
#             return
#         print(json.dumps(response_data, indent=4), flush=True)
#         return response_data['ocs']['data']


def get_registered_listeners():
    nc = NextcloudApp()
    try:
        aaa = nc.ocs("GET", "/ocs/v1.php/apps/webhook_listeners/api/v1/webhooks")
    except Exception as e:
        raise
    return aaa
    # with httpx.Client() as client:
    #     method = 'GET'
    #     path = ''
    #     url = os.environ["NEXTCLOUD_URL"] + path
    #     userid = os.environ["NEXTCLOUD_USERID"]
    #     secret = os.environ["NEXTCLOUD_SECRET"]
    #     headers = {
    #         'AUTHORIZATION-APP-API': base64.b64encode(bytes(f"{userid}:{secret}", 'utf-8')).decode('utf-8'),
    #         'OCS-APIREQUEST': 'true',
    #         'EX-APP-VERSION': 'v1.0.0',
    #         'EX-APP-ID': os.environ['APP_ID'],
    #         'AA-VERSION': 'v2.3.0'
    #     }
    #     print(f"sync_API_nextcloud_request: {url} - {method}", flush=True)
    #     response = client.request(
    #         method=method,
    #         url=url,
    #         params={'format': 'json'},
    #         headers=headers,
    #     )
    #     print(
    #         f"sync_API_nextcloud_request: method={method}, path={path}, status={response.status_code}",
    #         flush=True
    #     )
    #     try:
    #         response_data = json.loads(response.content)
    #     except json.JSONDecodeError as e:
    #         print(f"Error parsing JSON: {e}")
    #         return []
    #     print(json.dumps(response_data, indent=4), flush=True)
    #     return response_data['ocs']['data']


# async def delete_listener(registered_listener):
#     async with httpx.AsyncClient() as client:
#         method = 'DELETE'
#         path = f"/ocs/v2.php/apps/webhook_listeners/api/v1/webhooks/{registered_listener['id']}"
#         url = os.environ["NEXTCLOUD_URL"] + path
#         userid = os.environ["NEXTCLOUD_USERID"]
#         secret = os.environ["NEXTCLOUD_SECRET"]
#
#         headers = {
#             'AUTHORIZATION-APP-API': base64.b64encode(bytes(f"{userid}:{secret}", 'utf-8')).decode('utf-8'),
#             'OCS-APIREQUEST': 'true',
#             'EX-APP-VERSION': 'v1.0.0',
#             'EX-APP-ID': os.environ['APP_ID'],
#             'AA-VERSION': 'v2.3.0'
#         }
#         print(f"sync_API_nextcloud_request: {url} - {method}", flush=True)
#         response = await client.request(
#             method=method,
#             url=url,
#             headers=headers,
#             params={'format': 'json'}
#         )
#         print(
#             f"sync_API_nextcloud_request: method={method}, path={path}, status={response.status_code}",
#             flush=True
#         )
#         try:
#             response_data = json.loads(response.content)
#         except json.JSONDecodeError as e:
#             print(f"Error parsing JSON: {e}")
#             return
#         print(json.dumps(response_data, indent=4), flush=True)
#         return response_data['ocs']['data']


if __name__ == "__main__":
    initialize_windmill()
    # Current working dir is set for the Service we are wrapping, so change we first for ExApp default one
    os.chdir(Path(__file__).parent)
    run_app(APP, log_level="info")  # Calling wrapper around `uvicorn.run`.
