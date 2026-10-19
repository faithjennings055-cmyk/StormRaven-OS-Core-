class Freya:
    def think_autonomously(self, data):
        if data['cpu'] > 90:
            return {"type": "command", "intent": "kill_bloatware"}
        return None

    def listen(self, user_input):
        return {"type": "chat", "content": "I am listening, Doctor.", "intent": "chat"}