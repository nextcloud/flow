# Flow: Seamless Automation for Nextcloud

Flow is a dynamic workflow automation application, carefully integrated into your Nextcloud environment. Built upon the powerful Windmill engine, Flow takes the robust capabilities of Windmill and adapts them for a smooth experience within Nextcloud, providing teams and individuals with the ability to automate, streamline, and enhance their workflows like never before.

> [!NOTE]
> **Requires [`AppAPI`](https://github.com/nextcloud/app_api) and `webhook_listeners` to be enabled to work.**

## Key Features of Flow

Flow brings a wealth of features designed to improve productivity and collaboration, with a particular focus on user-friendliness and scalability:

### 1. **Drag-and-Drop Workflow Builder**
   - Create complex workflows with ease using a highly intuitive drag-and-drop interface. Whether you're automating document management, team notifications, or custom processes, Flow's visual workflow designer ensures anyone can build and modify workflows with minimal effort.

### 2. **Automate Repetitive Tasks**
   - Save time and resources by automating common repetitive tasks. With Flow, you can schedule tasks to run on specific conditions or set up trigger-based actions to run automatically, reducing manual interventions and enhancing efficiency.

### 3. **Seamless Integration with Nextcloud**
   - As a fully integrated part of Nextcloud, Flow works effortlessly alongside other applications in your Nextcloud environment. Automate tasks related to file management, collaboration, communication, and more, all within the same familiar platform.

### 4. **Built on the Windmill Engine**
   - Flow leverages the robust backend of Windmill, an established workflow automation platform, which powers its capabilities for scalability, efficiency, and reliability. Windmill’s foundation ensures that Flow inherits an array of advanced features while being customized for seamless use within Nextcloud.

### 5. **Real-Time Workflow Monitoring**
   - Keep track of the progress of your workflows in real-time with detailed analytics and dashboards. Monitor performance, track errors, and ensure that every task is executed smoothly without delays.

### 6. **Flexible Scheduling and Triggers**
   - Flow allows you to set up flexible schedules for tasks, trigger workflows based on specific events, and monitor their execution in real time. With Flow’s built-in scheduler, you can execute workflows on demand, at predefined intervals, or when specific criteria are met.

## Benefits of Using Flow

Flow is more than just a workflow tool. It's a productivity powerhouse designed to work seamlessly in the Nextcloud environment, enhancing everything from document management to team collaboration.

### 1. **Centralized Workflow Automation**
   - Flow helps you centralize all your workflow automation needs within Nextcloud, reducing the need for external tools and ensuring a smoother, more integrated experience for users.

### 2. **Boosted Team Collaboration**
   - By automating notifications, approvals, and task assignments, Flow ensures that your team stays in sync and focused on the tasks that matter most, reducing the time spent on administrative overhead.

### 3. **Scalable for Any Team Size**
   - Whether you’re working with a small team or an entire organization, Flow is built to scale. Thanks to Windmill’s proven engine, Flow can handle workflows of any complexity, ensuring that your automation can grow alongside your team.

### 4. **Security and Privacy First**
   - Built within the secure framework of Nextcloud, Flow ensures that all your workflows and automation are handled with the highest level of security and data protection. Your data stays within your Nextcloud environment, respecting your organization’s privacy policies.

## Getting Started

Flow is designed to be easy to set up and use. Follow these steps to get started:

### Step 1: Install Flow in Nextcloud
To install Flow, navigate to the Nextcloud AppStore and search for **Flow**. Install the app and [`follow the instructions`](https://docs.nextcloud.com/server/latest/admin_manual/windmill_workflows/index.html) to complete the setup.

### Step 2: Configure Workflows
Once Flow is installed, you can start creating workflows by accessing the Flow tab within Nextcloud. Use the drag-and-drop builder to configure your desired workflows, add conditions, and set triggers.

### Step 3: Automate and Optimize
After creating your workflows, sit back and let Flow do the heavy lifting. You can monitor all automated tasks in real time and optimize them as needed.

## Advanced Features

For users familiar with Windmill, Flow offers additional advanced features that enhance automation capabilities within Nextcloud:

- **API Integrations**: Connect Flow with external applications through API integrations, allowing for even more customization and control.
- **Custom Scripting**: Write custom scripts to add to workflows, giving you full control over your automation processes.
- **Error Handling**: Flow includes error detection and handling mechanisms that ensure smooth execution and notify you of any issues during workflow execution.

## FAQ

### Specific environment options to control ExApp behavior

> [!NOTE]
>
> This is only supported starting from Nextcloud version `30.0.2` and `Flow 1.1.0` version 

**Q: How can I control the number of Windmill workers?**  
**A:** You can set the `NUM_WORKERS` environment variable. The default value is `number_of_cpu_cores * 2`.

**Q: I want to use an external PGSQL database instead of the bundled one in the container. Can I?**  
**A:** You can configure it by setting the `DATABASE_URI` environment variable in the following format:  
`postgres://DB_USER:DB_PASS@localhost:5432/DB_NAME`.

## Contributing

We welcome contributions from the community! If you're interested in helping improve Flow, please feel free to submit a pull request or open an issue on our GitHub repository. We’re constantly working to improve the functionality and capabilities of Flow, and your feedback is invaluable.
