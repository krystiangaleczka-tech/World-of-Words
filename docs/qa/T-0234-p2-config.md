# T-0234 P2 defaults

Added 26 defaults in seven canonical prefix registries, copying documented types,
ranges and owners. Existing hint/unlock JSON is unchanged; all entries are nonremote.
Daily reward is an inactive shared table value. Small IAP pack is a documented starting
amount, not store approval; no P3 packs, products or native adapters are activated.

Two integration tests exercise actual shipped defaults, RewardTable interoperability,
canonical unlock/consent ordering and validated metadata. Initial make check failed only
because the existing tools test fixed the old nine-key count. Under S5 the owner explicitly
approved adding that test to scope and updating its expectation to 35 in revision 2.

Final full make check and scope results are recorded in the PR. Independent review and CI
remain required before merge. T-0230 merged dependency status is reconciled to done.
