Feature: Forge UI side-by-side preview
  The Cirrus deployment can expose the Forge UI beside the current OpenClaw UI
  before the relay and OpenClaw replacement work is enabled.

  Rule: While the Forge UI preview is enabled without the Forge relay, the deployment shall expose only the static Forge UI container.

    Scenario: Static Forge UI is routable without relay dependencies
      Given the committed Forge UI manifest is applied to OpenShift
      When the Forge UI route is created
      Then the route serves the static Forge UI container
      And relay, injector, and OpenClaw gateway dependencies are not required

  Rule: Where the Forge relay is enabled, the saw-agent deployment shall proxy Forge UI API requests to the VM-hosted relay.

    Scenario: Forge UI is connected to the VM-hosted relay
      Given saw-agent exposes OpenClaw through the raw local forward
      And the Forge relay image is configured
      When saw-agent provisioning starts the Forge UI preview
      Then the Forge relay listens on a dedicated loopback port
      And the Forge UI route serves relay JSON from the API config endpoint

  Rule: While the Forge UI preview is enabled, the deployment shall preserve the existing OpenClaw authenticated route.

    Scenario: Forge UI route is side-by-side with OpenClaw
      Given saw-agent already exposes OpenClaw through the authenticated userport
      When the Forge UI preview is deployed
      Then the OpenClaw userport route remains unchanged
      And the Forge UI uses a separate route host

  Rule: While namespace permissions prevent Deployment creation, saw-agent provisioning shall expose the Forge UI from inside the agent VM.

    Scenario: Forge UI is hosted through the saw-agent service
      Given saw-agent can expose named service ports through Cirrus
      When saw-agent provisioning starts the Forge UI preview
      Then the Forge UI listens on a dedicated saw-agent port
      And the Forge UI route targets the saw-agent service instead of a Deployment

  Rule: If the Forge UI preview fails to start or become ready, then saw-agent provisioning shall print Forge UI service and container diagnostics.

    Scenario: Forge UI startup failure is diagnosable
      Given saw-agent provisioning includes the VM-hosted Forge UI preview
      When the Forge UI preview is not ready
      Then the provisioning log includes Forge UI user service diagnostics
      And the provisioning log includes Forge UI container diagnostics
