# Flow: Seamless Automation for Nextcloud

Flow is a dynamic workflow automation application, carefully integrated into your Nextcloud environment. Built upon the powerful Windmill engine, Flow adapts the robust capabilities of Windmill for a smooth experience within Nextcloud, providing teams and individuals with the ability to automate, streamline, and enhance their workflows like never before.

> **Note:**
> **Requires the `AppAPI` and `webhooks_listener` apps to be enabled to work properly.**

## Key Features of Flow

Flow brings a wealth of features designed to improve productivity and collaboration, with a particular focus on user-friendliness and scalability:

### 1. **Drag-and-Drop Workflow Builder**

- Create complex workflows with ease using a highly intuitive drag-and-drop interface. Whether you're automating document management, team notifications, or custom processes, Flow's visual workflow designer ensures anyone can build and modify workflows with minimal effort.

### 2. **Automate Repetitive Tasks**

- Save time and resources by automating common repetitive tasks. With Flow, you can schedule tasks to run on specific conditions or set up trigger-based actions to run automatically, reducing manual interventions and enhancing efficiency.

### 3. **Seamless Integration with Nextcloud**

- As a fully integrated part of Nextcloud, Flow works effortlessly alongside other applications in your Nextcloud environment. Automate tasks related to file management, collaboration, communication, and more—all within the same familiar platform.

### 4. **Built on the Windmill Engine**

- Flow leverages the robust backend of Windmill, an established workflow automation platform, powering its capabilities for scalability, efficiency, and reliability. Windmill’s foundation ensures that Flow inherits an array of advanced features while being customized for seamless use within Nextcloud.

### 5. **Real-Time Workflow Monitoring**

- Keep track of the progress of your workflows in real-time with detailed analytics and dashboards. Monitor performance, track errors, and ensure that every task is executed smoothly without delays.

### 6. **Flexible Scheduling and Triggers**

- Flow allows you to set up flexible schedules for tasks, trigger workflows based on specific events, and monitor their execution in real-time. With Flow’s built-in scheduler, you can execute workflows on demand, at predefined intervals, or when specific criteria are met.

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
> This is only supported starting from Nextcloud version `30.0.2` and Flow version `1.1.0`

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

## Contributing

We welcome contributions from the community! If you're interested in helping improve Flow, please feel free to submit a pull request or open an issue on our GitHub repository. We’re constantly working to improve the functionality and capabilities of Flow, and your feedback is invaluable.
