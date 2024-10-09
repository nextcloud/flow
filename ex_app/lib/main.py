"""Windmill as an ExApp"""

import asyncio
import contextlib
import json
import logging
import os
import random
import string
import typing
from base64 import b64decode
from contextlib import asynccontextmanager
from pathlib import Path
from time import sleep

import httpx
from fastapi import BackgroundTasks, Depends, FastAPI, Request, responses
from nc_py_api import NextcloudApp, NextcloudException
from nc_py_api.ex_app import (
    nc_app,
    persistent_storage,
    run_app,
    setup_nextcloud_logging,
)
from nc_py_api.ex_app.integration_fastapi import AppAPIAuthMiddleware, fetch_models_task
from starlette.responses import FileResponse, Response

# os.environ["NEXTCLOUD_URL"] = "http://nextcloud.local/index.php"
# os.environ["APP_HOST"] = "0.0.0.0"
# os.environ["APP_ID"] = "flow"
# os.environ["APP_SECRET"] = "12345"  # noqa
# os.environ["APP_PORT"] = "23001"

logging.basicConfig(
    level=logging.WARNING,
    format="[%(funcName)s]: %(message)s",
    datefmt="%H:%M:%S",
)
LOGGER = logging.getLogger("flow")
LOGGER.setLevel(logging.DEBUG)

DEFAULT_USER_EMAIL = "admin@windmill.dev"
USERS_STORAGE_PATH = Path(persistent_storage()).joinpath("windmill_users_config.json")
USERS_STORAGE = {}
print("[DEBUG]: USERS_STORAGE_PATH=", str(USERS_STORAGE_PATH), flush=True)
if USERS_STORAGE_PATH.exists():
    with open(USERS_STORAGE_PATH, encoding="utf-8") as __f:
        USERS_STORAGE.update(json.load(__f))


def get_user_email(user_name: str) -> str:
    return f"{user_name}@windmill.dev"


def add_user_to_storage(user_email: str, password: str, token: str = "") -> None:
    USERS_STORAGE[user_email] = {"password": password, "token": token}
    with open(USERS_STORAGE_PATH, "w", encoding="utf-8") as f:
        json.dump(USERS_STORAGE, f, indent=4)


async def create_user(user_name: str) -> str:
    LOGGER.info(user_name)
    password = generate_random_string()
    user_email = get_user_email(user_name)
    async with httpx.AsyncClient() as client:
        await client.request(
            method="POST",
            url="http://127.0.0.1:8000/api/users/create",
            json={
                "email": user_email,
                "password": password,
                "super_admin": True,
                "name": user_name,
            },
            cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
        )
        r = await client.post(
            url="http://127.0.0.1:8000/api/auth/login",
            json={"email": user_email, "password": password},
        )
        add_user_to_storage(user_email, password, r.text)
    return r.text


async def login_user(user_email: str, password: str) -> str:
    LOGGER.debug(user_email)
    async with httpx.AsyncClient() as client:
        r = await client.post(
            url="http://127.0.0.1:8000/api/auth/login",
            json={"email": user_email, "password": password},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"login_user: {r.text}")
        return r.text


def login_user_sync(user_email: str, password: str) -> str:
    LOGGER.debug(user_email)
    with httpx.Client() as client:
        r = client.post(
            url="http://127.0.0.1:8000/api/auth/login",
            json={"email": user_email, "password": password},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"login_user: {r.text}")
        return r.text


async def check_token(token: str) -> bool:
    async with httpx.AsyncClient() as client:
        r = await client.get("http://127.0.0.1:8000/api/users/whoami", cookies={"token": token})
        return bool(r.status_code < 400)


def check_token_sync(token: str) -> bool:
    with httpx.Client() as client:
        r = client.get("http://127.0.0.1:8000/api/users/whoami", cookies={"token": token})
        return bool(r.status_code < 400)


def get_valid_user_token_sync(user_email: str) -> str:
    token = USERS_STORAGE[user_email]["token"]
    if check_token_sync(token):
        return token
    user_password = USERS_STORAGE[user_email]["password"]
    token = login_user_sync(user_email, user_password)
    add_user_to_storage(user_email, user_password, token)
    return token


async def provision_user(request: Request, create_missing_user: bool) -> None:
    if "token" in request.cookies:
        LOGGER.debug("Token is present: %s", request.cookies["token"])
        if (await check_token(request.cookies["token"])) is True:
            return
        LOGGER.debug("Token is invalid: %s", request.cookies["token"])

    user_name = get_windmill_username_from_request(request)
    if not user_name:
        LOGGER.debug("`username` is missing in the request to ExApp. Headers: %s", request.headers)
        return
    user_email = get_user_email(user_name)
    if user_email in USERS_STORAGE:
        windmill_token_valid = await check_token(USERS_STORAGE[user_email]["token"])
        if not USERS_STORAGE[user_email]["token"] or windmill_token_valid is False:
            if not create_missing_user:
                LOGGER.debug("Do not creating user due to specified flag.")
                return
            user_password = USERS_STORAGE[user_email]["password"]
            add_user_to_storage(user_email, user_password, await login_user(user_email, user_password))
    else:
        await create_user(user_name)
    request.cookies["token"] = USERS_STORAGE[user_email]["token"]
    LOGGER.debug("Adding token(%s) to request", request.cookies["token"])


@asynccontextmanager
async def lifespan(_app: FastAPI):
    setup_nextcloud_logging("flow", logging_level=logging.WARNING)
    _t = asyncio.create_task(start_background_webhooks_syncing())  # noqa
    yield


APP = FastAPI(lifespan=lifespan)
APP.add_middleware(AppAPIAuthMiddleware)  # noqa


def get_windmill_username_from_request(request: Request) -> str:
    auth_aa = b64decode(request.headers.get("AUTHORIZATION-APP-API", "")).decode("UTF-8")
    try:
        username, _ = auth_aa.split(":", maxsplit=1)
    except ValueError:
        username = ""
    if not username:
        return ""
    return "wapp_" + username


def enabled_handler(enabled: bool, nc: NextcloudApp) -> str:
    if enabled:
        LOGGER.info("Hello from %s", nc.app_cfg.app_name)
        nc.ui.resources.set_script("top_menu", "flow", "ex_app/js/flow-main")
        nc.ui.top_menu.register("flow", "Workflow Engine", "ex_app/img/app.svg", True)
    else:
        LOGGER.info("Bye bye from %s", nc.app_cfg.app_name)
        nc.ui.resources.delete_script("top_menu", "flow", "ex_app/js/flow-main")
        nc.ui.top_menu.unregister("flow")
        nc.webhooks.unregister_all()
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


async def proxy_request_to_windmill(request: Request, path: str, path_prefix: str = ""):
    async with httpx.AsyncClient() as client:
        url = f"http://127.0.0.1:8000{path_prefix}/{path}"
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
        LOGGER.debug("%s %s/%s -> %s", request.method, path_prefix, path, response.status_code)
        response_header = dict(response.headers)
        response_header.pop("transfer-encoding", None)
        return Response(content=response.content, status_code=response.status_code, headers=response_header)


@APP.api_route("/api/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH", "TRACE"])
async def proxy_backend_requests(request: Request, path: str):
    LOGGER.debug("%s %s\nCookies: %s", request.method, path, request.cookies)
    await provision_user(request, False)
    return await proxy_request_to_windmill(request, path, "/api")


@APP.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH", "TRACE"])
async def proxy_frontend_requests(request: Request, path: str):
    LOGGER.debug("%s %s\nCookies: %s", request.method, path, request.cookies)
    await provision_user(request, True)
    file_server_path = ""
    if path.startswith("ex_app"):
        file_server_path = Path("../../" + path)
    elif not path:
        file_server_path = Path("/static_frontend/200.html").joinpath(path)
    elif Path("/static_frontend/").joinpath(path).is_file():
        file_server_path = Path("/static_frontend/").joinpath(path)

    if file_server_path:
        LOGGER.debug("proxy_FRONTEND_requests: <OK> Returning: %s", file_server_path)
        response = FileResponse(str(file_server_path))
    else:
        LOGGER.debug("proxy_FRONTEND_requests: <LOCAL FILE MISSING> Routing(%s) to the backend", path)
        response = await proxy_request_to_windmill(request, path)
    response.headers["content-security-policy"] = "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;"
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
        add_user_to_storage(DEFAULT_USER_EMAIL, new_default_password, default_token)
        r = httpx.post(
            url="http://127.0.0.1:8000/api/users/tokens/create",
            json={"label": "NC_PERSISTENT"},
            cookies={"token": default_token},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"initialize_windmill: can not create persistent token, {r.text}")
        default_token = r.text
        add_user_to_storage(DEFAULT_USER_EMAIL, new_default_password, default_token)
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
    while True:
        try:
            _webhooks_syncing()
        except Exception:  # noqa
            LOGGER.exception("Exception occurred", stack_info=True)
            sleep(60)


def _webhooks_syncing():
    workspace = "nextcloud"

    while True:
        nc = NextcloudApp()
        if not nc.enabled_state:
            print("ExApp is disabled, sleeping for 5 minutes")
            sleep(5 * 60)
            continue
        LOGGER.debug("Running workflow sync")
        token = get_valid_user_token_sync(DEFAULT_USER_EMAIL)
        flow_paths = get_flow_paths(workspace, token)
        LOGGER.debug("flow_paths:\n%s", flow_paths)
        expected_listeners = get_expected_listeners(workspace, token, flow_paths)
        LOGGER.debug("expected_listeners:\n%s", json.dumps(expected_listeners, indent=4))
        registered_listeners = get_registered_listeners()
        LOGGER.debug("get_registered_listeners:\n%s", json.dumps(registered_listeners, indent=4))
        for expected_listener in expected_listeners:
            expected_listener["filters"] = _preprocess_webhook_event_filter(expected_listener["filters"])
            registered_listeners_for_uri = get_registered_listeners_for_uri(
                expected_listener["webhook"], registered_listeners
            )
            for event in expected_listener["events"]:
                listener = next(filter(lambda listener: listener["event"] == event, registered_listeners_for_uri), None)
                if listener is not None:
                    listener["eventFilter"] = _preprocess_webhook_event_filter(listener["eventFilter"])
                    if listener["eventFilter"] != expected_listener["filters"]:
                        LOGGER.debug("before update_listener:\n%s", json.dumps(listener))
                        update_listener(listener, expected_listener["filters"], token)
                else:
                    register_listener(event, expected_listener["filters"], expected_listener["webhook"], token)
        for registered_listener in registered_listeners:
            if registered_listener["appId"] == nc.app_cfg.app_name:  # noqa
                if (
                    next(
                        filter(
                            lambda expected_listener: registered_listener["uri"] == expected_listener["webhook"]
                            and registered_listener["event"] in expected_listener["events"],
                            expected_listeners,
                        ),
                        None,
                    )
                    is None
                ):
                    delete_listener(registered_listener)
        sleep(30)


def _preprocess_webhook_event_filter(event_filter):
    if event_filter in (None, {}):
        return []
    return event_filter


def get_flow_paths(workspace: str, token: str) -> list[str]:
    method = "GET"
    path = f"w/{workspace}/flows/list"
    flow_paths = []
    with httpx.Client() as client:
        url = f"http://127.0.0.1:8000/api/{path}"
        headers = {"Authorization": f"Bearer {token}"}
        response = client.request(
            method=method,
            url=url,
            params={"per_page": 100},
            headers=headers,
        )
        LOGGER.debug("%s %s -> %s", method, path, response.status_code)
        try:
            response_data = json.loads(response.content)
            for flow in response_data:
                flow_paths.append(flow["path"])
        except json.JSONDecodeError:
            LOGGER.exception("Error parsing JSON", stack_info=True)
    return flow_paths


def get_expected_listeners(workspace: str, token: str, flow_paths: list[str]) -> list[dict]:
    flows = []
    for flow_path in flow_paths:
        with httpx.Client() as client:
            method = "GET"
            path = f"w/{workspace}/flows/get/{flow_path}"
            url = f"http://127.0.0.1:8000/api/{path}"
            headers = {"Authorization": f"Bearer {token}"}
            response = client.request(
                method=method,
                url=url,
                params={"per_page": 100},
                headers=headers,
            )
            LOGGER.debug("%s %s -> %s", method, path, response.status_code)
            try:
                response_data = json.loads(response.content)
            except json.JSONDecodeError:
                LOGGER.exception("Error parsing JSON", stack_info=True)
                return []
            first_module = response_data["value"]["modules"][0]
            if (
                first_module.get("summary", "") == "CORE:LISTEN_TO_EVENT"
                and first_module["value"]["input_transforms"]["events"]["type"] == "static"
                and first_module["value"]["input_transforms"]["filters"]["type"] == "static"
            ):
                webhook = f"/api/w/{workspace}/jobs/run/f/{flow_path}"
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


def register_listener(event, event_filter, webhook, token: str) -> dict:
    LOGGER.debug("%s - %s: %s", webhook, event, json.dumps(event_filter, indent=4))
    try:
        r = NextcloudApp().webhooks.register(
            "POST",
            webhook,
            event,
            event_filter=event_filter,
            auth_method="header",
            auth_data={"Authorization": f"Bearer {token}"},
        )
    except NextcloudException:
        LOGGER.exception("Exception during registering webhook", stack_info=True)
        return {}
    LOGGER.debug(json.dumps(r._raw_data, indent=4))  # noqa
    return r._raw_data  # noqa


def update_listener(registered_listener: dict, event_filter, token: str) -> dict:
    LOGGER.debug(
        "%s - %s: %s", registered_listener["uri"], registered_listener["event"], json.dumps(event_filter, indent=4)
    )
    try:
        r = NextcloudApp().webhooks.update(
            registered_listener["id"],
            "POST",
            registered_listener["uri"],
            registered_listener["event"],
            event_filter=event_filter,
            auth_method="header",
            auth_data={"Authorization": f"Bearer {token}"},
        )
    except NextcloudException:
        LOGGER.exception("Exception during updating webhook", stack_info=True)
        return {}
    LOGGER.debug(json.dumps(r._raw_data, indent=4))  # noqa
    return r._raw_data  # noqa


def get_registered_listeners():
    nc = NextcloudApp()
    r = nc.ocs("GET", "/ocs/v1.php/apps/webhook_listeners/api/v1/webhooks")
    for i in r:  # we need the same format as in `get_expected_listeners(workspace, token, flow_paths)`
        if not i["eventFilter"]:
            i["eventFilter"] = None  # replace [] with None
    return r


def delete_listener(registered_listener: dict) -> bool:
    r = NextcloudApp().webhooks.unregister(registered_listener["id"])
    if r:
        LOGGER.debug("removed registered listener with id=%d", registered_listener["id"])
    return r


def create_nextcloud_auth_variable() -> bool:
    r = httpx.post(
        url="http://127.0.0.1:8000/api/w/nextcloud/variables/create",
        cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
        json={
            "path": "u/admin/exapp_token",
            "value": os.environ["APP_SECRET"],
            "is_secret": True,
            "is_oauth": False,
            "description": "ExApp Authentication Variable",
        },
    )
    if r.status_code >= 400:
        LOGGER.critical("Can not create Nextcloud Auth Variable: %s %s", r.status_code, r.text)
        return False
    return True


def update_nextcloud_auth_variable() -> bool:
    r = httpx.post(
        url="http://127.0.0.1:8000/api/w/nextcloud/variables/update/u/admin/exapp_token",
        cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
        json={"value": os.environ["APP_SECRET"]},
    )
    if r.status_code >= 400:
        LOGGER.critical("Can not update Nextcloud Auth Variable: %s %s", r.status_code, r.text)
        return False
    return True


def create_nextcloud_auth_resource() -> bool:
    r = httpx.post(
        url="http://127.0.0.1:8000/api/w/nextcloud/resources/create",
        cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
        json={
            "path": "u/admin/exapp_resource",
            "resource_type": "nextcloud",
            "baseUrl": "unknown",
            "description": "ExApp Authentication Resource",
            "value": {"username": "flow_app", "password": "$var:u/admin/exapp_token"},
        },
    )
    if r.status_code >= 400:
        LOGGER.critical("Can not create Nextcloud Auth Resource: %s %s", r.status_code, r.text)
        return False
    return True


def create_nextcloud_resource():
    r = httpx.get(
        url="http://127.0.0.1:8000/api/w/nextcloud/variables/exists/u/admin/exapp_token",
        cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
    )
    if r.status_code >= 400:
        LOGGER.critical("Can not check for Nextcloud Auth Variable: %s %s", r.status_code, r.text)
        return
    if r.text.lower() == "false":
        LOGGER.info("Creating Nextcloud Auth variable")
        if create_nextcloud_auth_variable() is False:
            return
    else:
        r = httpx.get(
            url="http://127.0.0.1:8000/api/w/nextcloud/variables/get_value/u/admin/exapp_token",
            cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
        )
        if r.status_code >= 400:
            LOGGER.critical("Can not get Nextcloud Auth Variable value: %s %s", r.status_code, r.text)
            return
        if r.text != os.environ["APP_SECRET"]:
            LOGGER.info("Updating Nextcloud Auth variable")
            if update_nextcloud_auth_variable() is False:
                return

    r = httpx.get(
        url="http://127.0.0.1:8000/api/w/nextcloud/resources/exists/u/admin/exapp_resource",
        cookies={"token": USERS_STORAGE["admin@windmill.dev"]["token"]},
    )
    if r.status_code >= 400:
        LOGGER.critical("Can not check for Nextcloud Auth Resource: %s %s", r.status_code, r.text)
    if r.text.lower() == "false":
        LOGGER.info("Creating Nextcloud Auth Resource")
        create_nextcloud_auth_resource()


if __name__ == "__main__":
    initialize_windmill()
    create_nextcloud_resource()
    # Current working dir is set for the Service we are wrapping, so change we first for ExApp default one
    os.chdir(Path(__file__).parent)
    run_app(APP, log_level="info")  # Calling wrapper around `uvicorn.run`.
