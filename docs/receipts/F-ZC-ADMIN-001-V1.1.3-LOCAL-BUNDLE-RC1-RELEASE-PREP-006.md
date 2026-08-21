# F-ZC-ADMIN-001 v1.1.3 local bundle RC1 release-preparation receipt

## Result

- Request: `REQ-20260815-ADMIN-V1.1.3-LOCAL-BUNDLE-RC1`.
- Feature: `F-ZC-ADMIN-001`.
- Status: `LOCAL_RELEASE_PREPARATION_COMPLETE`.
- Linux candidate: `LOCAL_ARTIFACT_VERIFIED_NOT_DEPLOYED`.
- Node runtime candidate: `LOCAL_RELEASE_CANDIDATE_NOT_DEPLOYED`.
- Alibaba Cloud staging/production: `NOT READY / NOT DEPLOYED`.
- Remote writes, upload, installation, service change, credential initialization, Git commit and Git push: not executed.

The completed auto-account work was included only after its formal task was `COMPLETE` and its shared lock was `RELEASED`. The Linux source was frozen in an isolated tree and excludes unrelated dirty worktree changes.

## Final artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc2.zip` | 61,538 | `3D793F6326E67A17D7239619086DD736A91C6A0020790E010A77D1FAA38BF727` |
| `build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc2.manifest.json` | 7,866 | `0D3E2A480EEA3D52DD042441574FECFDB069C8EE2043E857F4CD6BDF3C117960` |
| `build/linux/candidates/v1.1.3-local-linux-rc1/JungleLawServer.x86_64` | 95,486,056 | `6D8768B5953EBCEFB5A5B5BFFA6A398CAAD056F1C506F80E9F01D2EF6948C14B` |
| `build/linux/candidates/v1.1.3-local-linux-rc1/manifest.json` | 14,190 | `1C7EAC93EFAE2C4249614D8A0502973B4D22E57B69AACABB887A4742CC9A4C9A` |
| `build/linux/candidates/v1.1.3-local-linux-rc1/PROVENANCE.md` | 11,300 | `F74F9856668988A4CE592798A7A5756F833A1781BB66BE3F235004BD7697CA88` |
| `build/linux/JungleLawServer-v1.1.3-local-linux-rc1.tar.gz` | 51,270,560 | `88C3B339FB1933A8B648E1C73B938B86A87B1AC5058A44F7B7138BE039ED3B0D` |
| `build/linux/JungleLawServer-v1.1.3-local-linux-rc1.tar.gz.sha256` | 112 | `6ED90462872F6B007F84A86373AD7D272BFD6642218B7AE5ABE5FCF8BCDC44CB` |

The Node ZIP was rebuilt twice and both ZIP SHA-256 values matched. The Linux archive was built independently from two separate WSL ext4 staging directories with normalized order, root name, timestamp, uid/gid, modes and gzip metadata; both archives were byte-identical with the final SHA-256 above.

## Final RAG binding

- Status: `READY`.
- Sources/chunks: 63 / 862.
- Golden evaluation: 16/16, mean recall 1.0, pass rate 1.0.
- Index signature: `76118cdcddd67bd9e178d77334403c0675e0ae01a6ffd86917824a5163c70222`.
- Gate receipt SHA-256: `8CC81F1BBB6869F42385A74886EE4EE4EFED7A8095CB90E1991A545D6EC301BE`.
- Task receipt SHA-256: `15753597B336F20A011F72CC1A1C8E86281FAD9A8BE0DF01DB70109BA7F40F91`.
- Context pack SHA-256: `A686F451EA63489F4C005E819C2FF11B9D8FB292AFC3E675BF3709708F7D61C9`.
- The final refresh includes the corrected `temp/rag` active-scope paths and final deployment verifier/aggregate hashes. The earlier pack was preserved but is excluded from the final signature.

## Accepted verification

- Node syntax: 8/8 PASS, log SHA-256 `8132ADC56E46CFDB694AA40D599640E64A8786DAD2AC9806A5158D4168E1CD88`.
- Node final suite: four consecutive saved 13/13 PASS runs; log hashes are recorded in the Linux manifest.
- Extracted Node package: 16/16 entries matched, 8/8 syntax checks passed, `server.mjs --help` passed, and strict forbidden-path/private-key checks passed.
- GDScript indentation: PASS, log SHA-256 `5CF7413F6CA34EB7149DB12F6BD65F9BB6A578BDAE6A90C96F8D9089636B873D`.
- Godot import/parse: PASS with zero hard-error hit, log SHA-256 `ECAF9360F7F4A598BBFC2128EA2E964E33C069AEE3AFCAFE254AAAA6B75AF58B`.
- Godot regression: 16/16 exit 0 and required markers present, summary SHA-256 `3890427CB7096ABB0B9FBDF80407EA69746B24A7FD0FD45AA62540A764B4E679`.
- Godot accepted export: exit 0, `[ DONE ] savepack`, zero hard-error hit, log SHA-256 `D4BC45BB6E20530EADF917DA10455FF5A25B0E9DF93A7BBC86CB8C110A8535F7`.
- Final deploy aggregate: bash syntax PASS, stop helper 9/9 PASS, log SHA-256 `F4821F2110423D83FD7C01E12CBC397F40425C9F813137AB59BAA0D4A883A7CC`.
- Accepted WSL matrix: three graceful stop/restart cycles, malformed/wrong-token/stale-PID rejection, raw-signal fail-closed, corrupt-authority rejection, foreign residual-lock rejection and full cleanup; summary SHA-256 `AB25CD8A26135EAAC011418FAFFFA7301D0790A04850B5B5ACE382F52D2B23E7`.
- Sealed archive WSL ext4 validation: ELF and sidecar PASS, manifest 13/13 PASS, archive modes PASS, forbidden content PASS, aggregate and stop helper 9/9 PASS; log SHA-256 `28D4FB2D488C8ADA2DAB8E5B26C535EC32EE8515018D0FC5890641A5E2D57530`.

## Excluded attempts and corrections

These attempts are retained and were not counted as acceptance:

1. Before the final Node source freeze, one full suite run had an `ownerLogin` fetch failure. A focused rerun, a complete rerun, three consecutive complete reruns and four additional saved 13/13 runs passed. The receipt does not claim the suite never failed.
2. Godot export attempt 1 exited 1 because the deliberately isolated AppData did not yet contain the 4.6.2 Linux templates. No ELF was produced. The exact machine templates were copied read-only into the isolated cache, and source/target hashes matched; real AppData was not modified.
3. WSL matrix attempt 1 incorrectly rejected `[::ffff:127.0.0.1]`, an IPv4-mapped loopback display. Independent cleanup audit passed.
4. The first candidate aggregate packaging check found that only the local verifier alias existed while the aggregate resolved the formal name. The candidate now retains both byte-identical names; the failed layout log is preserved and excluded.
5. WSL matrix attempt 2 completed the behavior scenarios but the final `pgrep -f` check matched the verifier's own argument list. Independent cleanup audit passed. The final verifier compares candidate real paths against `/proc/<pid>/exe` and attempt 3 passed.
6. The first post-seal extraction validation used a DrvFS evidence directory and therefore observed synthetic mode 777 despite correct tar headers. Its manifest, ELF and aggregate checks passed, but the attempt is excluded. The fresh WSL ext4 extraction validated the real archived 755/644 modes and passed; its temporary directory was removed.

## Security and remaining deployment gates

- No username/password, TLS private key, Alibaba Cloud key, SSH private key, player authority database, snapshot, resource queue, Node state or `node_modules` is packaged.
- The requested weak administrator password was not accepted, stored or packaged. Owner initialization requires the approved secret channel and current password policy.
- Alibaba Cloud still lacks an approved deployment owner, SSH alias, isolated service/release paths, domain/TLS decision, monitoring owner, backup capacity, rollback proof and staging write authorization.
- Real external login, placement data collection, balance recommendation quality, targeted/all-account grants, persistence, systemd 239 restart and rollback remain Alibaba Cloud staging acceptance work.
- `staging_remote_writes` and production remote-write authorization remain false. This receipt does not claim a website is online and does not provide a deployment URL.
