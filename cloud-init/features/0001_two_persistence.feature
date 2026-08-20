Feature: VM two persistent integration state
  The Cirrus cloud-init package can attach a persistent disk to VM two so
  integration secrets survive VM recreation while code remains reproducible.

  Rule: While VM two is provisioned, Cirrus cloud-init shall mount the two-persist PVC before integration provisioning starts.

    Scenario: VM two receives the persistent integration disk
      Given the committed Server two manifest references the two-persist PVC
      When VM two cloud-init prepares integration storage
      Then VM two mounts the persistent disk before running saw-provision.service

  Rule: If the persistent integration disk is blank, then VM two cloud-init shall format it exactly once.

    Scenario: Blank persistent disk is initialized safely
      Given VM two receives an unformatted persistent disk
      When VM two cloud-init prepares integration storage
      Then VM two formats the disk before mounting it

  Rule: While integration provisioning runs, the integration playbook shall preserve an existing provider key.

    Scenario: Existing provider key survives reprovisioning
      Given VM two already has a non-empty provider key
      When integration provisioning runs again
      Then the existing provider key remains unchanged
