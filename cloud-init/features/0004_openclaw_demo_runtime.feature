Feature: OpenClaw demo runtime provisioning

  Rule: Where demo CSB mode is enabled, the agent provisioning shall launch OpenClaw with the demo entrypoint and persistent sandbox state.

    Scenario: Demo runtime uses persistent state and the CSB entrypoint
      Given the agent VM is configured for OpenClaw demo CSB mode
      When the OpenClaw sandbox is provisioned
      Then OpenClaw state is stored on the persistent sandbox volume
      And the demo CSB entrypoint starts the gateway

  Rule: If stale OpenClaw state exists outside the persistent sandbox volume, then the agent provisioning shall avoid using it for the demo runtime.

    Scenario: Legacy state does not drive the demo runtime
      Given the agent VM contains legacy OpenClaw state
      When the OpenClaw sandbox is provisioned in demo CSB mode
      Then the demo runtime ignores the legacy OpenClaw state path
