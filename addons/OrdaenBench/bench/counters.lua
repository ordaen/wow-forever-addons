-- What the scenarios count, for the checks: how often a component mounted, rendered or a watch ran, and invariants
-- seen broken. Shared by the scenario components and the plan.
return { mounts = 0, renders = 0, runs = 0, violations = 0 }
