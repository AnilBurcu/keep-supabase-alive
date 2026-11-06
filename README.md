# Keep Supabase Alive

Supabase pauses free plan projects after about 7 days without database
activity. When that happens your app stops working until you log in and
restore the project by hand.

This repo fixes that with a scheduled GitHub Actions workflow. Once a day it
makes one tiny database write to each of your projects. That counts as
activity, so Supabase never pauses them.

- No server and no paid service. GitHub Actions free tier is more than enough.
- Your database never grows. The ping updates a single row in place.
- Only the anon (public) key is used. The service_role key is never needed.
- If a ping fails, GitHub sends you an email.

## How it works

Each project gets a one-row table called `_keepalive` and a function called
`keep_alive()`. The workflow calls the function through the Supabase REST API
once a day with your anon key. The function writes the current time into that
one row.

The table has RLS enabled with no policies, so nobody can read or change it
directly through the API. The function is the only way in, and the only thing
it can do is update a timestamp.

## Setup

About 10 minutes for the first project, then about 2 minutes per extra project.

### 1. Create your copy of this repo

Click "Use this template" at the top of this page, then "Create a new
repository". A private repo is fine and recommended (see the FAQ for why).

### 2. Run the SQL in every Supabase project

Open your Supabase dashboard, go to SQL Editor, paste the contents of
[setup.sql](setup.sql), and click Run. Do this once per project.

### 3. Put your project URLs in the workflow

Open `.github/workflows/keep-alive.yml` in your repo and edit the matrix
section. One block per project:

```yaml
- name: project-1
  url: https://abcdefghijklmnop.supabase.co
  key_secret: ANON_KEY_PROJECT_1
```

`name` is just a label. `url` is your project URL from Settings > API in the
Supabase dashboard. `key_secret` is the name of the GitHub secret that will
hold that project's anon key (next step). Add as many blocks as you need and
remove the ones you don't.

### 4. Add your anon keys as secrets

In your repo go to Settings > Secrets and variables > Actions > New repository
secret. Create one secret per project:

- Name: must match the `key_secret` value from the workflow, for example
  `ANON_KEY_PROJECT_1`
- Value: the anon public key from Settings > API in the Supabase dashboard

Do not put the service_role key anywhere. It is not needed and this workflow
never asks for it.

### 5. Test it

Go to the Actions tab, pick "Supabase Keep-Alive" on the left, and click
"Run workflow". Every job should turn green.

If a job fails:

| Error | Cause |
|---|---|
| exit code 6 | Wrong project URL (host not found) |
| HTTP 401 | Secret missing, or its name does not match `key_secret` |
| HTTP 404 | The SQL from step 2 was not run in that project |

### 6. Done

The workflow now runs by itself every day at 03:23 UTC. You can change the
time by editing the cron line. If a run fails, GitHub emails you.

## Check that it is working

Run this in the SQL Editor of any project:

```sql
select * from _keepalive;
```

The `pinged_at` column shows when the last ping landed. Check it a day later
and you will see that it moved on its own.

## FAQ

**Is it safe to put the anon key in GitHub secrets?**
Yes. The anon key is meant to be public and already ships inside your app or
website. Keeping it in a secret instead of the YAML file is just good hygiene.

**Will this bloat my database?**
No. The table always contains exactly one row and the daily ping overwrites
it. There is nothing to clean up.

**Is this allowed by Supabase?**
The Supabase docs list making API calls to your project as a way to prevent
pausing, so this does exactly what they suggest. If you want a guaranteed
no-pause setup, their Pro plan removes pausing entirely.

**Why a write and not a simple GET?**
Pause detection looks at real database activity. A bare request to the
project URL without a key is rejected at the gateway and may never reach the
database. A small write leaves no room for doubt.

**My repo is public and the schedule stopped after a while. Why?**
GitHub disables scheduled workflows in public repos after 60 days without any
repo activity. It emails you first, and one click re-enables it. Private
repos do not have this rule, which is why a private copy is recommended.

**How much GitHub Actions time does this use?**
Around 1 minute per day. The free tier for private repos alone is 2000
minutes per month.

**Does this back up my database?**
No. It only keeps the project awake, and free plan projects have no backups
of their own. For a daily backup, use
[supabase-free-backup](https://github.com/AnilBurcu/supabase-free-backup). Its
daily dump also counts as database activity, so you do not need both.

## License

MIT
