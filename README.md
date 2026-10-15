# SQL injection lab with Docker Compose: attack a weak web app, fix the query and prove the fix

[![check](https://github.com/mitsurutech/lab-sqli-fix/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-sqli-fix/actions/workflows/check.yml)

A ready-made **SQL injection lab** for classrooms, from the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), where schools and colleges give every student their own databases, containers and terminal in the browser. Each student gets their own copy of a small shop whose product search is **vulnerable to SQL injection**, attacks it from a terminal with `curl`, **fixes the code to use a parameterised query**, restarts the shop and shows that the attack now fails while normal searches still work. Nothing is installed and nobody else's machine is at risk.

It is one `docker-compose` file, `compose.yaml`, built from a single public Python image, and it runs the same on your own machine as it does on the platform, where every student gets a private copy with no way out to the internet.

## The one rule

**Attack your own copy and nothing else.** Everything in this lab runs inside your own private copy, which has no route to the internet and none to any other student, so the only thing you can reach is the shop the lab started for you. Never point a tool at a website, a network or a machine you do not own: in the UK that is an offence under the [Computer Misuse Act 1990](https://www.legislation.gov.uk/ukpga/1990/18/contents), and most countries have a law like it. Learning how a weakness works is how you write code that does not have it, and a good first conversation in a class is why this rule exists and what responsible disclosure looks like.

## What is in it

| Service | Image | Memory | What it is |
| --- | --- | --- | --- |
| `app` | [`python:3.12.15-alpine`](https://hub.docker.com/_/python) | 96 MB | a shop's search page written with Python's standard library and SQLite |

There is nothing third-party to attack: the shop is about eighty lines written by the compose file's own entrypoint, because a lab is made of images alone and may not mount a file or build one. The program is written into a **named volume** on the first start only, so the fix a student makes is never put back, and it is still there after the lab is stopped and started again. The shop starts in about four seconds and uses about 12 MB when idle.

The shop has two tables. `products` has five products for sale and two that are not (a staff discount card and an unreleased drone). `users` has two accounts with their passwords, which no search should ever show.

## Using it on the platform

The [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning) gives every student their own copy of a lab, in the browser, with a terminal beside it.

**To try it:** open the [container page](https://mitsurutech.co.uk/container), find this lab in **Sample labs** and press Start. No account is needed to try one.

**To set it as work for a class:**

1. In your module, make a task of type **Lab** and choose **In a GitHub repository**.
2. Give `https://github.com/mitsurutech/lab-sqli-fix` with the branch `main`. The compose file is the default, `compose.yaml`. Fork the repository first if you want to change the file.
3. Publish. Every student's copy starts from the commit you published, so a later change here does not alter a lab already set.
4. Say in the task what to hand in (see [For teachers](#for-teachers)), and assign it like any other task.

The help manual's [page for this lab](https://mitsurutech.co.uk/help/lab-sqli-fix), its [guide to container labs](https://mitsurutech.co.uk/help/labs) and its [guide to the security labs](https://mitsurutech.co.uk/help/security-labs) cover the rest. No college account yet? [Your first year is free](https://mitsurutech.co.uk/pricing) for up to 50 students, and [signing up](https://mitsurutech.co.uk/signup) takes an email address.

## Running it on your own machine

You need Docker with the Compose plugin. The first start downloads the image.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Open <http://localhost:8000> for the search page. `local.yaml` publishes the port on `127.0.0.1` only, so the shop is reachable from your own computer and from nowhere else. Stop it with `Ctrl-C`, and remove it, volume included, with `docker compose -f compose.yaml -f local.yaml down -v`. On the platform the terminal reaches the shop by its service name, `app`; on your own machine use `localhost:8000` in the commands below and `docker compose exec app` for `docker exec app`.

## Working through it

1. **Search normally.** `curl -s -G --data-urlencode "q=pen" http://app:8000/search` prints the pen and its price.
2. **Break out of the query.** The search term is pasted into the SQL text, so a quote ends the string. Try `x' OR 1=1 --` and the shop lists the two products that are not for sale. Try `x' UNION SELECT username, password FROM users --` and it prints every account's password.
3. **Read the code.** `docker exec app cat /tmp/app/app.py` shows it. Find the line that builds the query.
4. **Fix it.** Use a parameterised query, so the term is sent to the database as data and never as SQL. Edit with `docker exec -it app vi /tmp/app/app.py`.
5. **Restart and prove it.** `docker restart app`, then repeat the attacks: they find nothing. Search for `Baker's`, a real product with an apostrophe in its name, which fails on the weak code and must work on yours.
6. **Ask the lab.** `docker exec app sh /tmp/app/lab-check` prints PASS or FAIL for each of the four things above.
7. **Start again if you want to.** `docker exec app rm /tmp/app/app.py`, then `docker restart app`, puts the weak code back. A program that no longer compiles is kept as `app.py.broken` and the weak one is written again, so a typing mistake never leaves the lab unable to start.

## For teachers

Nothing in this lab is marked automatically. The student hands in evidence and you mark it, the way you mark any other lab.

**Ask for evidence in two halves.** First, proof of the work: the output of the attack before the fix and after it, and the output of `docker exec app sh /tmp/app/lab-check` at the end. Second, the understanding: the line they changed, and a sentence in their own words on why the new one cannot be injected, what an attacker could have done with the old one, and what else would help (the account the application connects as, passwords that are never stored in plain text).

**Where it sits in a course.** This suits secure coding and web application security units: input handling, parameterised queries and the principle that data must never be run as code. It also supports the legal and ethical side of a unit: authorisation and scope, the Computer Misuse Act 1990 and responsible disclosure. Check your own awarding body's unit for the exact wording; none is quoted here.

**Who sees what.** These labs are often used with students aged 16 and 17. A copy is private to the student who started it. A member of staff who teaches the module can open it to see what the student has done, and opening a student's work is written to the access log, which the student can read.

## What does not work in a lab

The lab has no way out to the internet. It has no second part on database privileges: SQLite has no accounts to grant to, and a lab has no internet to install a client for a server database from. The shop is given 96 MB.

## Troubleshooting

- **The shop does not answer straight after Start.** Wait a few seconds and press Open again: the lab reports itself ready only once the shop answers.
- **`vi` is unfamiliar.** Press `i` to type, `Esc` to stop typing, then `:wq` and Enter to save and leave (`:q!` leaves without saving).
- **A search with a quote or a space fails in `curl`.** Use `-G --data-urlencode "q=..."`, which encodes the term for you.
- **On your own machine, port 8000 is already in use.** Change the left-hand number in `local.yaml`, for example `127.0.0.1:8001:8000`, and open that port instead.

## Checking the lab

`test/check.sh` starts the lab the way the platform's runner starts every service (all capabilities dropped, `no-new-privileges`, a process limit, memory limits, and no way out to the internet) and then plays a student through it from inside its network: the attacks work on the weak code, the fix is made in the running container, the shop is restarted, the attacks fail and normal use works, the fix survives a stop and a start, and the weak code can be put back. It needs Docker and runs on every push, which is the badge at the top.

```bash
test/check.sh
```

## Versions and licences

The shop runs on the official [Python](https://www.python.org) image, `python:3.12.15-alpine`, under the Python Software Foundation licence. It is run unmodified from its own public image, pinned to a version, and nothing is distributed by this repository.

The compose file, the tests and this documentation are MIT licensed, see [LICENSE](LICENSE): copy it, change it, teach with it.

## About

Made by [Mitsuru Technologies](https://mitsurutech.co.uk) for the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL and Linux in the browser for schools and colleges, with container labs, web apps deployed from GitHub, and quizzes that mark themselves. Try code with no account in the [playground](https://mitsurutech.co.uk/playground).

More labs from the same place: [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-harden-nginx](https://github.com/mitsurutech/lab-harden-nginx), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) and [lab-sample](https://github.com/mitsurutech/lab-sample).
