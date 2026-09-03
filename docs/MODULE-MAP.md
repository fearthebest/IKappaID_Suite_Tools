# Suite Tools module map (soft hub)

**Frontend (IKappaID_UI):** `IKUI_SoftBody` — contentRect / stack / pageBands / masterDetail / section / pillRow / fieldAction / finish.

**Feature UI (this repo):** `IKST_SoftTool_*` — SoftBody-native workspace paint. SoftPageHost + Registers prefer SoftTool over Job*.

**Helpers:** `IKST_Job*` — dispatch, request, lists, arm. Soft `build` entry points alias SoftTool (live path never paints dock).

**Shell:** `IKST_Hub` → `IKUI_Shell` → `IKST_SoftPageHost` → HubNav → SoftTool / Page*.

See also: [`SOFT-HUB-LAW.md`](SOFT-HUB-LAW.md), [`HUB-NAV-SCHEMA.md`](HUB-NAV-SCHEMA.md), IKappaID_UI `docs/MODULE-MAP.md` + `docs/API.md`.
