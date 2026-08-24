Feature: External Forge UI boundary
  Forge UI is deployed outside the saw-agent VM, while saw-agent exposes only
  the OpenClaw authenticated route and internal provisioning diagnostics.

  Rule: While Forge UI is hosted remotely, the saw-agent deployment shall not expose Forge UI ports or workloads.

    Scenario: saw-agent keeps only OpenClaw and diagnostics ports
      Given the saw-agent server manifest is rendered
      When the deployment is applied
      Then the saw-agent service exposes the OpenClaw userport
      And the saw-agent service exposes the provisioning diagnostics port
      And the saw-agent service does not expose Forge UI ports

    Scenario: cloud-init does not deploy Forge UI workloads
      Given the saw-agent provisioning playbook is rendered
      When saw-agent provisioning runs
      Then Forge UI systemd units are not installed
      And Forge UI containers are not launched
      And Forge UI route manifests are not shipped
