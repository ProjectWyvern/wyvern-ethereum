In response to the issues found in the audit report:

1. Indeed, with the current EVM design, it is impossible to guarantee that a contract will never receive Ether. This was an oversight on our part. The balance assertion has been removed.

2. This is intentional. When paying fees in the protocol token, Exchange users have the option to pay no fees. Relayers, which host off-chain orderbooks, can require particular fees for submission to their orderbooks.

3. Relayers can choose to whitelist or blacklist tokens to prevent user confusion, so implementing token restrictions at the protocol layer is unnecessary. The recommendation of user caution is well-received.
