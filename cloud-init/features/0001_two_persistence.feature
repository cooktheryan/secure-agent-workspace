Feature: VM two persistent integration state
  The Cirrus cloud-init package can attach a persistent disk to VM two so
  integration secrets survive VM recreation while code remains reproducible.

  Rule: While VM two is provisioned, Cirrus cloud-init shall attach the two-persist PVC without mounting it directly.

    Scenario: VM two receives the persistent integration disk
      Given the committed Server two manifest references the two-persist PVC
      When VM two starts from cloud-init
      Then VM two receives the persistent disk for integration provisioning

  Rule: If the persistent integration disk is blank, then the integration playbook shall format it exactly once.

    Scenario: Blank persistent disk is initialized safely
      Given VM two receives an unformatted persistent disk
      When integration provisioning prepares persistent storage
      Then VM two formats the disk before mounting it

  Rule: While integration provisioning runs, the integration playbook shall mount persistent integration directories before writing proxy configuration.

    Scenario: Integration configuration is written to persistent storage
      Given VM two receives the persistent integration disk
      When integration provisioning prepares proxy configuration
      Then VM two stores integration configuration on the persistent disk

  Rule: While integration provisioning runs, the integration playbook shall preserve an existing provider key.

    Scenario: Existing provider key survives reprovisioning
      Given VM two already has a non-empty provider key
      When integration provisioning runs again
      Then the existing provider key remains unchanged
