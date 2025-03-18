<!--
  - SPDX-FileCopyrightText: 2024 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: MIT
-->
# Flow: Seamless Automation for Nextcloud

[![REUSE status](https://api.reuse.software/badge/github.com/nextcloud/flow)](https://api.reuse.software/info/github.com/nextcloud/flow)

Nextcloud Flow is a set of intuitive automation components that allow organizations to automate and streamline internal workflows.

Through easy low-code and no-code interfaces it enables users to effortlessly automate routine tasks, ease data entry and manipulation and reduce manual work.

It includes components designed for a variety of businesses needs and at various scales, from SME to large enterprises.

1. Users can build simple mini-apps to manage structured data through the no-code interface in the Tables app.
2. Users can automate actions on a variety of triggers through no-code interfaces in the Flow user settings.
3. Administrators can additionally configure file access controls to automatically block unauthorized access to sensitive data.
4. Business process annalists and administrators have access to the powerful business automation features built on the open source **Windmill** tool, capable of modeling large business processes that require interaction with internal and external services.

This app provides an easy way to install the Windmill based Business Process Automation component of Flow.

> **Note:**
> **Requires the `AppAPI` and `webhooks_listener` apps to be enabled to work properly.**

## Getting Started

Flow is designed to be easy to set up and use. Follow these steps to get started:

To install Flow, navigate to the Nextcloud App Store and search for **Flow**. Install the app and [follow the instructions](https://docs.nextcloud.com/server/latest/admin_manual/windmill_workflows/index.html) to complete the setup.

## Advanced Features

For users familiar with Windmill, Flow offers additional advanced features that enhance automation capabilities within Nextcloud:

- **API Integrations**: Connect Flow with external applications through API integrations, allowing for even more customization and control.
- **Custom Scripting**: Write custom scripts to add to workflows, giving you full control over your automation processes.
- **Error Handling**: Flow includes error detection and handling mechanisms that ensure smooth execution and notify you of any issues during workflow execution.

## FAQ

### Specific Environment Options to Control ExApp Behavior

> **Note:**
>
> This is only supported starting from Nextcloud version `32.0.0`

**Q: How can I control the number of Windmill workers?**
**A:** You can set the `NUM_WORKERS` environment variable. The default value is `number_of_cpu_cores * 2`.

**Q: I want to use an external PostgreSQL database instead of the bundled one in the container. Can I?**
**A:** Yes, you can configure it by setting the `EXTERNAL_DATABASE` environment variable in the following format:
`postgres://DB_USER:DB_PASS@localhost:5432/DB_NAME`

### Manual Deployment

> **Note:**
>
> This method can also be used for enterprise or custom scaled Windmill setups.

**Prerequisites:**

- Nextcloud instance with `AppAPI` and `webhooks_listener` apps enabled.
- Python 3.10 or higher installed on the server.
- Git installed on the server.

Follow these steps to manually deploy Flow without Docker:

1. **Register the Deploy Daemon in AppAPI**

   First, register the Deploy Daemon in AppAPI with the `manual-install` type. Refer to the Nextcloud documentation for detailed instructions: [AppAPI Manual Install](todo)

2. **Clone the Repository and Install Dependencies**

   Clone the Flow repository:

   ```bash
   git clone https://github.com/nextcloud/flow.git
   ```

   Navigate into the cloned directory, create a Python virtual environment, and install the required dependencies:

   ```bash
   cd flow
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Install Windmill**

   Install Windmill by following the official instructions: [Setup Windmill on Localhost](https://www.windmill.dev/docs/advanced/self_host#setup-windmill-on-localhost)

   **Note:** Windmill should be in its default state, with the default user `admin@windmill.dev` and password `changeme`. If you have changed the administrator username/password, adjust the `DEFAULT_USER_EMAIL` and `DEFAULT_USER_PASSWORD` variables in the `ex_app/lib/main.py` file accordingly.

4. **Configure ExApp Environment Variables**

   Set the required ExApp environment variables (`NEXTCLOUD_URL`, `APP_HOST`, `APP_PORT`, `APP_SECRET`) or modify them directly in the script at the top of `ex_app/lib/main.py`. Refer to the Nextcloud documentation for more details: [ExApp Configuration](todo)

5. **Set the `WINDMILL_URL` Environment Variable**

   Define the `WINDMILL_URL` environment variable or set it in the script. This variable specifies the location of the Windmill instance you deployed in step 3.

6. **Adjust Windmill Version (Optional)**

   **Note:** If you are using a non-standard version of Windmill from the ExApp, please adjust its version in the `Makefile` by editing the line under the `init` target:

   ```makefile
   git -c advice.detachedHead=False clone -b v1.394.4 https://github.com/windmill-labs/windmill.git windmill_src
   ```

   Replace `v1.394.4` with your desired Windmill version.

7. **Initialize Windmill Source and Build Frontend**

   Run the following commands from the cloned `flow` repository to clone Windmill into the `windmill_src` folder and build the frontend:

   ```bash
   make init
   make static_frontend
   ```

   These commands will:

   - Clone the Windmill source code into `windmill_src`.
   - Build the frontend assets and create the `static_frontend` folder, which will be served by ExApp as the Windmill frontend.

8. **Run the ExApp and Register with Nextcloud**

   Start the ExApp main script:

   ```bash
   python ex_app/lib/main.py
   ```

   In a new terminal window (while keeping the ExApp running), execute the registration command to register the ExApp with Nextcloud:

   ```bash
   make register
   ```

   This registers the ExApp in Nextcloud for operation without Docker.

9. **Access Windmill in Nextcloud**

   Windmill should now appear within your Nextcloud instance, accessible via the Flow app.

### Notes for Development Setup

*Windmill will be deployed as per its official documentation. The following steps simplify its integration with Nextcloud's development setup.*

1. In the `.env` file used for deploying Windmill's Docker Compose containers, set the desired Windmill version. The current version can be found in the `Makefile` (e.g., `1.394.4`). Adjust the following line accordingly:

   ```bash
   WM_IMAGE=ghcr.io/windmill-labs/windmill:1.394.4
   ```

2. Add the `master_default` network (or the network name used for Nextcloud in your Julius `nextcloud-docker-dev` setup) to each container in Windmill's `docker-compose.yml`.

   Additionally, append the following lines to the bottom of Windmill's `docker-compose.yml` file:

   ```yaml
   networks:
     master_default:
       external: true
   ```

3. Change the `Caddy` exposed port in Windmill's `docker-compose.yml` from `80` to `8388` (the port that is set in `main.py` script)
4. Deploy Windmill, then proceed to step 8 in the Manual Deployment section described above.

## Contributing

We welcome contributions from the community! If you're interested in helping improve Flow, please feel free to submit a pull request or open an issue on our GitHub repository. We’re constantly working to improve the functionality and capabilities of Flow, and your feedback is invaluable.
