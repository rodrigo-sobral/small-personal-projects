---
name: cover-letter-generator
description: Generates a styled PDF cover letter (RodrigoSobralCL.pdf) for Rodrigo Sobral whenever a job posting URL is shared. Use this skill immediately when the user shares any job posting link and asks for a cover letter, message, expression of interest, or any application material — even if phrased casually ("write something for this", "same spirit as before", "rewrite for this post"). Always fetch the URL, generate the message, and produce the PDF without asking for clarification first. This skill encodes Rodrigo's voice, background, and the proven message formula used across all his applications.
---

# Cover Letter Generator

Produces `RodrigoSobralCL.pdf` — a single-page PDF cover letter in Rodrigo Sobral's established voice and format.

---

## About Rodrigo Sobral

Use this as context for every letter. Do not repeat it verbatim in the output.

**Contact:** +41 78 210 90 28 | contact@rodrigo-sobral.com | rodrigo-sobral.com  
**Location:** Geneva, Switzerland  
**Portfolio:** https://rodrigo-sobral.com  

**Current role:** DevOps Engineer at CERN (Jan 2024 – Present), Geneva  
- Built and operates ATS SWAN — a Kubernetes-based Jupyter platform for scientific computing  
- Manages the main SWAN instance (~400 daily users, 54-node production clusters)  
- Implemented Custom Software Environments, Falco threat detection, AI agent integrations  
- Stack: Python, Kubernetes, Helm, ArgoCD, Docker, Terraform, Grafana, Prometheus, Falco, OpenStack  

**Previous role:** Backend Developer at UCNext (Oct 2022 – Oct 2023), Coimbra  
- Delivered production platforms serving ~34,000 users (UCCompetitions, UCApply, MyUC, UCAnalytics, UCDigitalSignature, UCID)  
- Stack: Python, PostgreSQL, Redis, REST APIs, AWS S3, SAP, Grafana  

**Education:**  
- M.Sc. Cybersecurity — University of Coimbra (2021–2023). Thesis: user behavioral patterns in cybersecurity  
- B.Sc. Computer Science — University of Coimbra (2018–2021)  
- Active CTF player on TryHackMe (pentesting, MITRE ATT&CK, exploitation, malware analysis, OSINT)  

**Certifications:** CKS (Certified Kubernetes Security Specialist), CKA (Certified Kubernetes Administrator), Cisco Networking Academy, Ethical Hacker  

**Languages:** Portuguese (native), English (fluent), Spanish (intermediate), French (basic A2)  

---

## Step 1 — Fetch the Job Posting

Always `web_fetch` the provided URL before writing anything. Extract:
- Company name (for salutation and opening)
- Role title
- Key mission, product, or business context
- Any specific tech stack, values, or culture signals

If the URL is blocked or returns no content, use `web_search` to find the company and role.

---

## Step 2 — Write the Message

Write **one paragraph** in Rodrigo's established voice. The formula that works:

1. **Open with the company's weight** — its legacy, scale, commercial position, mission, or the specific problem it's solving. Make it concrete (numbers, names, facts). Never open with "I".
2. **Frame the role's stakes** — what breaks or succeeds depending on how well this job is done. Connect the engineering work to real-world consequences (financial, operational, human).
3. **Close with first-person conviction** — a direct statement of intent that shows hunger, ownership, and ambition. Often ends with a line that ties engineering quality to business outcome.

### Voice principles
- **Sharp, not corporate.** No "I am excited to apply" or "I believe I would be a great fit."
- **Confident, not arrogant.** Show hunger without overselling.
- **Human, not templated.** The best lines feel earned, not polished.
- **Capitalist undertone.** Frame value in terms of growth, returns, competitive advantage, market position — not just "making an impact."
- **Specific > generic.** One concrete fact about the company beats three adjectives.
- **Never clichéd.** If a phrase could appear in any cover letter, cut it.
- **No mid-sentence dashes.** Never use an em dash (or hyphen standing in for one) to join two clauses, it's a dead giveaway of AI writing. Use a comma, a period, or rephrase into two sentences instead.
  - This does NOT apply to normal compound-word hyphens (e.g. "54-node", "Kubernetes-based") — those stay.
  - Example fix: "data pipelines that never blink — one bad feed, one late reconciliation, and a quant strategy is trading on stale information" → "data pipelines that never blink, because one bad feed or one late reconciliation means a quant strategy is trading on stale information"
  - Another: "reliability isn't a feature you bolt on afterward — it's the architecture itself" → "reliability isn't a feature you bolt on afterward, it's the architecture itself" (or split into two sentences)

### Proven closing patterns (vary, don't copy verbatim)
- "I want to be the engineer who [specific contribution], because when [X], [business outcome]."
- "I want to [own/build/hold] that [layer/line/foundation], because [company] deserves [engineering standard] that matches [its ambition/legacy/scale]."

### Personal context to weave in when relevant
- If the role is in **gaming** (PlayStation, Rockstar, Bethesda): Rodrigo has played PlayStation since childhood; Skyrim shaped his teenage years; these brands have genuine personal meaning to him.
- If the role is in **security**: He approaches it as a craft, not a compliance checkbox. CKS + M.Sc. in Cybersecurity is a rare combination.
- If the role is in **finance/fintech**: He is genuinely interested in macro economics and wealth creation; frames engineering value in financial terms naturally.
- If the role is at a **research institution or deep-tech company**: CERN is the anchor — operating at that scale gives him an authentic reference point.

---

## Step 3 — Produce the PDF

Use `reportlab` to generate the PDF. Follow the exact format below.

### PDF Format Spec

- **Page size:** A4
- **Margins:** 2.5 cm left/right, 2.5 cm top/bottom
- **Font:** Helvetica (body), Helvetica-Bold (signature name)
- **Font size:** 11pt body, 9pt contact line
- **Line spacing:** 1.5× leading on the body paragraph
- **Salutation:** `Dear <Company Name> Hiring Team,`
- **Body:** The generated paragraph (justified alignment)
- **Sign-off block:**
  ```
  Best regards,
  Rodrigo Sobral
  +41 78 210 90 28 | contact@rodrigo-sobral.com | rodrigo-sobral.com
  ```
### Output Path — OS Detection (always run this first)

```python
import os, sys, platform

def get_output_path(filename="RodrigoSobralCL.pdf") -> str:
    system = platform.system()
    home = os.path.expanduser("~")
    if system == "Darwin":  # macOS → Downloads
        return os.path.join(home, "Downloads", filename)
    elif system == "Windows":  # Windows → Desktop
        return os.path.join(home, "Desktop", filename)
    else:  # Linux → Desktop (fallback to home if Desktop doesn't exist)
        desktop = os.path.join(home, "Desktop")
        return os.path.join(desktop if os.path.isdir(desktop) else home, filename)

OUTPUT_PATH = get_output_path()
```

Also copy to `/mnt/user-data/outputs/RodrigoSobralCL.pdf` so `present_files` can serve it — but the primary save location is always the OS-aware path above.

### PDF Generation Code Template

```python
import os, sys, platform, shutil
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib import colors

def get_output_path(filename="RodrigoSobralCL.pdf") -> str:
    system = platform.system()
    home = os.path.expanduser("~")
    if system == "Darwin":
        return os.path.join(home, "Downloads", filename)
    elif system == "Windows":
        return os.path.join(home, "Desktop", filename)
    else:
        desktop = os.path.join(home, "Desktop")
        return os.path.join(desktop if os.path.isdir(desktop) else home, filename)

def generate_cover_letter(company_name: str, message: str):
    output_path = get_output_path()

    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=2.5*cm,
        rightMargin=2.5*cm,
        topMargin=2.5*cm,
        bottomMargin=2.5*cm,
    )

    body_style = ParagraphStyle(
        'Body',
        fontName='Helvetica',
        fontSize=11,
        leading=17,
        alignment=TA_JUSTIFY,
        spaceAfter=0,
    )

    salutation_style = ParagraphStyle(
        'Salutation',
        fontName='Helvetica',
        fontSize=11,
        leading=17,
        alignment=TA_LEFT,
        spaceAfter=12,
    )

    name_style = ParagraphStyle(
        'Name',
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        alignment=TA_LEFT,
    )

    contact_style = ParagraphStyle(
        'Contact',
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        alignment=TA_LEFT,
        textColor=colors.HexColor('#444444'),
    )

    story = [
        Paragraph(f"Dear {company_name} Hiring Team,", salutation_style),
        Paragraph(message, body_style),
        Spacer(1, 24),
        Paragraph("Best regards,", body_style),
        Spacer(1, 6),
        Paragraph("Rodrigo Sobral", name_style),
        Paragraph("+41 78 210 90 28 | contact@rodrigo-sobral.com | rodrigo-sobral.com", contact_style),
    ]

    doc.build(story)

    # Also copy to outputs dir for present_files
    outputs_dir = "/mnt/user-data/outputs"
    if os.path.isdir(outputs_dir):
        shutil.copy(output_path, os.path.join(outputs_dir, "RodrigoSobralCL.pdf"))

    return output_path

path = generate_cover_letter(
    company_name="<COMPANY>",
    message="<GENERATED_PARAGRAPH>",
)
print(f"Saved to: {path}")
```
```

---

## Step 4 — Present the File

Call `present_files` with `/mnt/user-data/outputs/RodrigoSobralCL.pdf` and add a one-line note with the company name and role.

---

## Quality Checklist

Before generating:
- [ ] Message opens with company/mission, not "I"
- [ ] At least one concrete fact (number, name, product) about the company
- [ ] Role's stakes are explicit — what goes wrong or right depending on this job
- [ ] Closing is direct, first-person, and shows ownership
- [ ] No clichés ("passionate", "excited to apply", "great fit", "team player")
- [ ] No em dashes joining clauses (compound-word hyphens like "54-node" are fine, use commas or split sentences for the rest)
- [ ] Capitalist thread is present (growth, returns, market position, value creation)
- [ ] One paragraph only
