Feature: OpenClaw SAW demo resource names
  The Cirrus cloud-init package can launch the OpenClaw SAW demo using the
  upstream demo's agent and integrations VM naming contract.

  Rule: While the OpenClaw SAW demo is deployed, Cirrus cloud-init shall name the agent VM saw-agent and the integrations VM saw-integ.

    Scenario: Demo VM manifests use upstream-aligned names
      Given the committed Cirrus Server manifests are rendered for a namespace
      When the OpenClaw SAW demo VMs are launched
      Then the agent Server is named saw-agent
      And the integrations Server is named saw-integ

  Rule: While the OpenClaw SAW demo is deployed, Cirrus cloud-init shall use Kubernetes Service DNS rather than VM IP addresses for inter-VM traffic.

    Scenario: Agent configuration targets the integrations Service DNS name
      Given the committed agent variables are rendered for a namespace
      When agent provisioning configures model traffic
      Then the endpoint references saw-integ through cluster Service DNS
