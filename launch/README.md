# Launch artifacts

This directory contains pre-written launch announcements ready to copy/paste on launch day. **Drafts only — not yet posted anywhere.**

## Files

| File | Where it gets posted | Tone |
|------|---------------------|------|
| `show-hn.md` | Hacker News (Show HN) | Punchy, factual, founder available for comments |
| `reddit-selfhosted.md` | r/selfhosted | Self-hoster-to-self-hoster, includes screenshots reference |
| `announce-twitter.md` | Twitter/X (thread) | Visual, tweet-sized chunks, link out to repo |

## Launch checklist

The order and timing matter — fastest signal-amplification path:

### Day -1 (pre-launch prep)

- [ ] Push the `v1.0.0` tag to `origin` (`git push --tags origin`)
- [ ] Create the v1.0.0 GitHub release with CHANGELOG excerpt as release notes
- [ ] Verify GitHub Pages is enabled on the repo (Settings → Pages → Source: GitHub Actions)
- [ ] Trigger `deploy-docs.yml` manually once to confirm `https://obstack.dev` (or the GitHub Pages URL) is live
- [ ] Capture all screenshots per `assets/screenshots/README.md` and embed in the README
- [ ] Set up Google Alerts for "obstack" so you see external mentions
- [ ] Have a fresh terminal with the stack running for live screenshot answers

### Day 0 (launch)

- [ ] **Morning, 9-10 AM ET (Tuesday-Thursday is best for HN):** Submit Show HN at `news.ycombinator.com/submit`
- [ ] Within 5 minutes, post first comment as the OP introducing yourself and inviting questions
- [ ] **Same day, 30 minutes after HN post:** Post on r/selfhosted
- [ ] **Same day, 1 hour after HN post:** Tweet/X the announcement thread
- [ ] **Throughout day:** Reply to every HN comment within 30 minutes — engagement keeps the post on the front page
- [ ] Take a brief break every 2 hours but check in often

### Day +1

- [ ] Recap thread on Twitter: "Yesterday we shipped... here's what we learned." Include any unexpected feedback.
- [ ] Reply to remaining HN comments
- [ ] Push any quick patches (typos, FAQ updates) as `v1.0.1`

### Week +1

- [ ] Submit obstack templates to:
  - Coolify Templates: <https://github.com/coollabsio/coolify> (pull request to their templates repo)
  - Dokploy Templates: <https://github.com/Dokploy/templates>
  - CapRover One-Click Apps: <https://github.com/caprover/one-click-apps>
- [ ] Follow up on any user-reported issues
- [ ] Consider writing the technical deep-dive blog post: *"How we fit Prometheus + VictoriaLogs + Tempo + Pyroscope on a 4 GB VPS"*

### Things to monitor

- HN front page rank (run a tab on `news.ycombinator.com`)
- GitHub stars (compare to the day-0 baseline)
- Reddit upvotes + comment count
- Docker Hub pulls (proxy for actual deploys)
- Twitter mentions / quote tweets

## Tone notes

- **Don't oversell.** "$20/month VPS" is a strong claim; back it with the measured 311 MB idle number.
- **Acknowledge competitors directly.** Not "obstack is better than X." More: "Here's where obstack differs and where competitors are still better."
- **Be honest about scope.** "Single-VPS only at v1; Standard / Scale / Enterprise profiles in future releases." HN catches overpromising in seconds.
- **Don't sneak in a paywall.** obstack is MIT, full stop. There's no "obstack Cloud" surprise behind a feature flag.

## Anti-patterns to avoid

- **"Show HN: A new way to do observability."** Generic, sounds salesy.
- **Listing every feature without context.** Pick the 3 most differentiated and lead with them.
- **Asking for stars on launch day.** Tacky. Stars come from engagement, not solicitation.
- **Posting at 3 AM ET.** US working hours (or early EU) get the most engagement.
- **Silence after posting.** A Show HN with no founder replies dies on the front page.
