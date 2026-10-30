# Support-page deployment packet — October 29, 2026

**Completed October 30, 2026 after explicit owner approval for deployment and Support URL.**

## Deployment result

- Production deployment `dpl_FKjVMUJN7mYtsUtEBTZv1svQ1ytK` is READY and aliased to
  `https://pickup-ucf-privacy.vercel.app`. Deployment URL:
  `https://pickup-ucf-privacy-2kidl5n2t-nurlanmnns-projects.vercel.app`.
- Unauthenticated system curl verified HTTPS 200 and exact source bytes for
  `/support.html`, all six existing files, and the two auth rewrites plus a
  retained synthetic session route. Referrer/nosniff headers, auth no-store,
  noindex/CSP and AASA JSON content type passed. No TLS bypass was used.
- Browser verification rendered the contact mailbox/policy links and expanded
  the Calendar FAQ successfully. Support source SHA256:
  `cd25e733e3c188ceba0605bf72367cceeea13458fa82f57c39d8f3beaccd6cec`.
- Saved only `https://pickup-ucf-privacy.vercel.app/support.html` in the public
  iOS 1.0 Support URL field. Reload confirmed persistence and disabled Save.
  Other fields were untouched; the version remains Prepare for Submission.
- Evidence: `/tmp/pickup-support-deploy-result.json`,
  `/tmp/pickup-support-live-verification.json`, `/tmp/pickup-support-live.png`,
  `/tmp/pickup-support-url-saved.png`. Previous production remains recorded in
  `/tmp/pickup-support-before-deploy.json`; rollback was not needed.

The preflight and execution scope below are retained as historical preparation.

## Concrete scope

Deploy the existing static `privacy-site/` to its already-linked Vercel project
**pickup-ucf-privacy**, production alias
**https://pickup-ucf-privacy.vercel.app**. The only site diff from the October22
production source `b8349d27b580d15ef8333509343ab44bba1a369b` is the new
88-line **`privacy-site/support.html`**, originally committed in `e890ba6`.
Proposed public URL: **https://pickup-ucf-privacy.vercel.app/support.html**.

The page contains the established public support mailbox, policy links and native
FAQ disclosures for account access, games/chat/notifications, independent Calendar
copies and safety controls. It has no JavaScript or third-party assets. The prior
local browser/narrow-layout/link/contrast checks are in the October28 device record;
source has not changed since those checks. Preview: `/tmp/pickup-support-preview.png`.

## Current read-only preflight

- Public support URL returns **404**; no deployment or App Store URL save is claimed.
- Six currently served files match local source byte-for-byte: index/privacy,
  terms, community guidelines, auth fallback, session fallback and AASA.
- `privacy-site/vercel.json` is unchanged. Existing auth/session rewrites and
  no-store/noindex/CSP auth protection, AASA content type and referrer headers remain.
- Authenticated cached Vercel CLI62.0.0 reports owner `nurlanmnn`. Linked project
  inspection confirms **pickup-ucf-privacy**, exact local project ID match, no
  framework and no root-directory override. No project/account setting was saved.
- Current production is **READY** deployment **dpl_CyuEUpV5p5HaVJ39Ty9MWgsJs9jZ**,
  URL `pickup-ucf-privacy-5r7rv8ste-nurlanmnns-projects.vercel.app`.
- Reports: `/tmp/pickup-support-deploy-preflight.json`,
  `/tmp/pickup-support-project-preflight.json`,
  `/tmp/pickup-support-production-preflight.json`.
  System curl preserved TLS validation; the local Python distribution's missing
  CA chain was not bypassed or changed.

## Execute after approval

Recheck clean site diff and linked target; deploy only from `privacy-site/` using
its existing Vercel binding. Do not modify Auth provider/redirect settings, backend
functions, migrations or secrets. After READY, independently re-fetch support and
all existing static routes/AASA, verify support rendering/FAQ/links and expected
headers, and confirm unchanged file hashes. Preserve the prior production
identifier for immediate scoped re-aliasing if route/content checks regress.

The approval covers the new public support page and the static deployment that
includes it. App Store metadata changes, external/public review and release remain
separate steps. Before setting the listing Support URL, establish that this exact
HTTPS page is publicly usable. No support-page approval has been inferred from
internal TestFlight authorization.
