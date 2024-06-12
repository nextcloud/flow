ARG WINDMILL_VERSION=1.342.0
FROM ghcr.io/windmill-labs/windmill:${WINDMILL_VERSION}
ARG WINDMILL_VERSION=1.342.0

RUN apt update && \
    apt install -y nano procps sudo wget

# Clone Windmill to build it's frontend with our custom URL for AppAPI
RUN git clone --depth 1 -b fix/frontend/relative-paths https://github.com/marcelklehr/windmill.git /windmill_tmp

RUN cd /windmill_tmp/frontend && \
    npm install

# Change svelte base URL
RUN cd /windmill_tmp/frontend && \
    basePath="/index.php/apps/app_api/proxy/windmill_app" && \
    configFilePath="svelte.config.js" && \
    sed -i "/kit: {/a \
            paths: {\
                base: '${basePath}'\
            }," "$configFilePath"

# Generate OpenAPI data
RUN cd /windmill_tmp/frontend && \
    npm run generate-backend-client

# Set URL for backend in generated OpenAPI data
RUN sed -i "s|BASE: '/api'|BASE: '/index.php/apps/app_api/proxy/windmill_app/api'|" /windmill_tmp/frontend/src/lib/gen/core/OpenAPI.ts

# Build Windmill's frontend
RUN cd /windmill_tmp/frontend && \
    NODE_OPTIONS=--max_old_space_size=8096 npm run build && \
    rm -rf /static_frontend /iframe && \
    mv build /iframe

COPY ex_app_scripts/init_pgsql.sh /ex_app_scripts/init_pgsql.sh
COPY ex_app_scripts/set_workers_num.sh /ex_app_scripts/set_workers_num.sh
COPY ex_app_scripts/entrypoint.sh /ex_app_scripts/entrypoint.sh

RUN chmod +x /ex_app_scripts/*.sh

COPY requirements.txt /ex_app_requirements.txt

ADD /ex_app/cs[s] /ex_app/css
ADD /ex_app/im[g] /ex_app/img
ADD /ex_app/j[s] /ex_app/js
ADD /ex_app/l10[n] /ex_app/l10n
ADD /ex_app/li[b] /ex_app/lib

RUN python3 -m pip install -r /ex_app_requirements.txt
RUN chmod +x /ex_app/lib/main.py

EXPOSE 8000
EXPOSE 9990

CMD ["/bin/sh", "/ex_app_scripts/entrypoint.sh", "/ex_app/lib/main.py", "windmill"]
