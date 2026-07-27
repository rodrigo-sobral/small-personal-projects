---
name: cern-ticket-summarizer
description: Summarizes CERN ServiceNow ticket threads (RQF.../INC... requests and incidents, e.g. SWAN/CERNBox support tickets) into a standard HTML snippet with "Requests/Incidents" and "Tasks" sections, ready to paste into a report or handover doc. Use this skill whenever the user pastes one or more ticket threads (blocks of dated comments with a header like "RQF3813283" or "INC1234567"), or asks to "summarize this ticket", "summarize these tickets", or "summarize this thread" — even if they don't use the word "skill" or mention the format explicitly. Always anonymizes customer names and attributes team members' replies to "we".
---

# CERN Ticket Thread Summarizer

Turns raw ServiceNow ticket thread exports into a short, standardized HTML summary for reports/handovers.

## Input format

The user will paste one or more ticket threads. Each thread looks like:

```
RQF3813283
28-05-2026 13:42:16 - Abbygale Grace SwadlingAdditional comments (Customer View)
Hi Tomas,
...
28-05-2026 13:26:36 - Abbygale Grace SwadlingAdditional comments (Customer View)
I am not able to open a new swan notebook...
```

- First line (or line containing it) is the ticket ID: `RQF\d+` or `INC\d+`.
- Comments are listed newest-first, each starting with a timestamp, author name, and "...Additional comments (Customer View)".
- A thread may have multiple tickets pasted one after another — treat each ticket ID block as a separate ticket.

## Output format

Produce this exact HTML structure (no markdown, no extra wrapping, no code fences in the final answer — give it as a plain HTML block the user can copy):

```html
<p><strong>Requests/Incidents:</strong></p>
<ul>
<li><a href="https:\/\/cern.service-now.com/service-portal?id=ticket&amp;n=RQF3813283">RQF3813283</a>: One to three sentence summary of the problem and how it was resolved.</li>
<li><a href="https:\/\/cern.service-now.com/service-portal?id=ticket&amp;n=INC1234567">INC1234567</a>: Summary for the second ticket, if there is one.</li>
</ul>
<p></p>
<p><strong>Tasks:</strong></p>
<ul>
<li></li>
</ul>
```

- One `<li>` per ticket in the Requests/Incidents list, in the same order they were given.
- The link always follows the pattern `https:\/\/cern.service-now.com/service-portal?id=ticket&amp;n=<TICKET_ID>` — same for both RQF and INC, just swap the ID. Keep the escaped `\/` and `&amp;` exactly as shown; don't "clean up" the escaping.
- Keep the empty `<p></p>` spacer line between the two sections.
- If there are no tasks to report, leave exactly one empty `<li></li>` in the Tasks list (as in the template) — don't delete the `<ul>`/`<li>` or leave it out.

## Summarization rules

- **Anonymize the customer.** Never use the customer's name (however it appears — full name, first name only, nickname/signature like "Abby"). Always refer to them as "the user".
- **Team members become "we".** The following people are internal team members; when they are the author of a comment, refer to their actions/replies as "we" (never by name):
  - Pedro Maximino
  - Tomas Roun
  - Rodrigo Sobral
  (If the user mentions a new teammate later, add them to this list for the rest of the session and treat them the same way.)
- **Keep it brief.** One to three sentences per ticket: what the problem/request was, and what the resolution or current status is. Don't narrate the back-and-forth turn by turn — synthesize.
- **Read the whole thread**, since comments are listed newest-first; understand the full arc (initial issue → clarifications → resolution) before summarizing.
- **Multiple tickets in one paste** each get their own `<li>` in the same output, in the order given — whether that's two tickets or a dozen, don't skip or merge any of them.
- **No team reply yet.** If every comment in the thread is from the customer (no team member has responded), don't invent a resolution — describe the problem/request, then state that the issue is under investigation.

## Tasks section

Leave the Tasks section as a single empty `<li></li>` **by default**. Only add a task line if the thread clearly mentions something still to be done by the team going forward — e.g. a patch, fix, or new feature that was mentioned as pending/planned (not already completed). Phrase each as a short actionable line, one `<li>` per task. If nothing like that appears, leave it empty — don't invent tasks from vague or resolved discussion.

## Delivering the output

This is short, copy-paste HTML meant to go straight into a ticketing/report tool — respond inline in the conversation inside a code block, not as a file/artifact.
