import random
import logging
import time

logging.basicConfig(level=logging.INFO, format='%(message)s')

class ToxicLeader:
    def __init__(self, name="Exec"):
        self.name = name
        self.failure_count = 0

        self.anonymous_leader = random.choice([
            "Brielle", "Cassidy", "Jordan", "Morgan", "Skyler", "Reese", "Harper", "Riley"
        ])

        self.blame_pool = [
            f"Blame {self.anonymous_leader}",
            "Blame the intern",
            "Blame marketing",
            "Blame IT",
            "Blame finance",
            "Blame the customer",
            "Blame the techs",
            "Blame the Client",
            "Blame a previous employee"
        ]
        self.blame_weights = [0.45, 0.1, 0.1, 0.1, 0.1, 0.04, 0.04, 0.04, 0.03]

        self.blame_explanations = {
            f"Blame {self.anonymous_leader}": "Singling out a single leader ignores systemic problems and stalls real fixes.",
            "Blame the intern": "Targeting the least experienced wastes talent and creates fear, not solutions.",
            "Blame marketing": "Marketing isn’t responsible for operational failures but gets scapegoated anyway.",
            "Blame IT": "IT often becomes the default punching bag for cross-departmental issues.",
            "Blame finance": "Financial controls are blamed to avoid ownership of strategic mistakes.",
            "Blame the customer": "Customer dissatisfaction is symptomatic, not the root cause.",
            "Blame the techs": "Frontline techs fix problems but get blamed instead of supported.",
            "Blame the Client": "Outsiders can be scapegoated unfairly when internal accountability is missing.",
            "Blame a previous employee": "Throwing past employees under the bus prevents addressing current leadership failures."
        }

        self.bad_ideas = [
            "Cut the budget in half and double the targets",
            "Fire someone at random to set an example",
            "Outsource everything immediately",
            "Ignore the data — go with your gut",
            "Schedule a 6-hour meeting to 'brainstorm responsibility'",
            "Launch a rebrand instead of fixing the product",
            "Force a return-to-office policy with no desks available",
            "Replace technical staff with motivational posters",
            "Create a task force to investigate the task force",
            "Make interns sign NDAs for broken onboarding processes",
            "Blame burnout on lack of hustle",
            "Implement 360-feedback but only for junior staff",
            "Reward loyalty with more unpaid overtime",
            "Say 'we're a family' then cut health benefits",
            "Hire a consultant to repeat what employees already said",
            "Start using buzzwords like 'synergize the deliverables'",
            "Install biometric time tracking for trust-building",
            "Announce layoffs on a Friday via calendar invite",
            "Remove coffee machines to boost productivity",
            "Make AI run the next team meeting",
            "The New Guy is the only competent Cyber professional we have, promote him",
            "Refuse to address issues because 'we tried that years ago and it didn’t work' — ignoring evolving context and new data"
        ]

        self.bad_idea_explanations = {
            "Cut the budget in half and double the targets": "Sets impossible goals without resources, ensuring failure.",
            "Fire someone at random to set an example": "Demoralizes the team and damages trust arbitrarily.",
            "Outsource everything immediately": "Sacrifices quality and institutional knowledge for short-term cost cuts.",
            "Ignore the data — go with your gut": "Dismisses facts and accountability in favor of whimsy.",
            "Schedule a 6-hour meeting to 'brainstorm responsibility'": "Wastes time while avoiding actual responsibility.",
            "Launch a rebrand instead of fixing the product": "Focuses on image over substance, eroding credibility.",
            "Force a return-to-office policy with no desks available": "Creates chaos and frustration without proper planning.",
            "Replace technical staff with motivational posters": "Undermines expertise with empty platitudes.",
            "Create a task force to investigate the task force": "Bureaucracy eats itself instead of solving problems.",
            "Make interns sign NDAs for broken onboarding processes": "Shifts blame to newbies rather than fixing core flaws.",
            "Blame burnout on lack of hustle": "Ignores systemic workload issues and punishes exhaustion.",
            "Implement 360-feedback but only for junior staff": "Creates unfair scrutiny while protecting senior failures.",
            "Reward loyalty with more unpaid overtime": "Exploits dedication, fostering resentment.",
            "Say 'we're a family' then cut health benefits": "Uses emotional manipulation to justify harmful cuts.",
            "Hire a consultant to repeat what employees already said": "Wastes money on redundant advice instead of action.",
            "Start using buzzwords like 'synergize the deliverables'": "Masks lack of direction with meaningless jargon.",
            "Install biometric time tracking for trust-building": "Signals distrust and creates a hostile environment.",
            "Announce layoffs on a Friday via calendar invite": "Shows callousness and lack of empathy.",
            "Remove coffee machines to boost productivity": "Mistakes morale boosters for distractions.",
            "Make AI run the next team meeting": "Dehumanizes communication and ignores nuance.",
            "The New Guy is the only competent Cyber professional we have, promote him": "Relies on one person rather than building team strength.",
            "Refuse to address issues because 'we tried that years ago and it didn’t work' — ignoring evolving context and new data": "Closes off problem solving based on outdated assumptions and avoids accountability."
        }

        self.good_idea = "Run a root cause analysis and fix the actual issue."

        self.failure_escalations = [
            "Morale has dropped to subatomic levels.",
            "The office microwave has now been declared a hostile actor.",
            "All department heads are in therapy.",
            "We are legally banned from using the word 'strategy' in meetings.",
            "IT has blocked leadership from editing Confluence.",
            "The intern is now the most competent person here.",
            "A developer deployed in protest and it improved production stability.",
            "Helpdesk staff are hiding under their desks (successfully).",
            "Employees created an underground Slack for real work.",
            "A Jira ticket was found in the breakroom with a resignation letter.",
            "The building Wi-Fi SSID is now 'RUNWHILEYOUCAN'.",
            "An engineer automated their own exit interview.",
            "HR filed a complaint against itself.",
            "Leadership replaced project deadlines with vibes.",
            "Someone scheduled a recurring meeting called 'Screaming'.",
            "The executive team started a podcast about visionary failure.",
            "Legal declared bankruptcy out of precaution.",
            "Recruiting is now handled by an Ouija board.",
            "The last working printer is in revolt.",
            f"{self.anonymous_leader}’s team now refers to them only as 'Our Last Hope'.",
            "In the absence of regular performance reviews, there will never be any feedback. If you ask, it’s your fault and always has been."
        ]

        self.failure_explanations = {
            "In the absence of regular performance reviews, there will never be any feedback. If you ask, it’s your fault and always has been.":
                ("This toxic mindset shifts the responsibility of feedback entirely onto employees, "
                 "ignoring leadership’s duty to provide regular, structured communication. It creates a blame culture, "
                 "stifles growth, and demoralizes staff."),
            # Other escalations can have explanations added similarly if desired.
        }

    def prompt_issue(self):
        issue = input("Describe the issue you're having: ")
        logging.info(f"{self.name}: Noted. Ignoring issue: \"{issue}\"")
        return issue

    def assign_blame(self):
        scapegoat = random.choices(self.blame_pool, weights=self.blame_weights, k=1)[0]
        logging.error(f"{self.name}: {scapegoat}. Explanation: {self.blame_explanations.get(scapegoat, 'No explanation available.')}")
        if scapegoat == f"Blame {self.anonymous_leader}":
            logging.error(f"{self.name}: Honestly, your leadership style is the central — and only — problem here.")
            logging.debug(f"{self.name}: We’ll probably need another meeting about how *you* handle meetings.")
        return scapegoat

    def make_decision(self):
        if random.random() <= 0.01:  # 1% chance of a good idea
            decision = self.good_idea
            logging.info(f"{self.name}: Against all odds... {decision}")
            return decision, False
        else:
            decision = random.choice(self.bad_ideas)
            logging.critical(f"{self.name}: Bold leadership decision — {decision}. Explanation: {self.bad_idea_explanations.get(decision, 'No explanation available.')}")
            return decision, True

    def escalate_failure(self):
        if self.failure_count < len(self.failure_escalations):
            escalation = self.failure_escalations[self.failure_count]
        else:
            escalation = "Organizational entropy has surpassed measurable thresholds."
        explanation = self.failure_explanations.get(escalation, "")
        self.failure_count += 1
        logging.warning(f"{self.name}: Side effect detected — {escalation}")
        if explanation:
            logging.warning(f"{self.name}: Explanation — {explanation}")

    def execute_plan(self):
        self.prompt_issue()
        scapegoat = self.assign_blame()
        # Stop cycle if blame on anonymous leader
        if scapegoat == f"Blame {self.anonymous_leader}":
            print("-" * 60)
            time.sleep(1)
            return

        decision, escalated = self.make_decision()
        if escalated:
            self.escalate_failure()
        print("-" * 60)
        time.sleep(1)


if __name__ == "__main__":
    exec_lead = ToxicLeader()
    for _ in range(10):
        exec_lead.execute_plan()
