const chatWindow = document.getElementById("chat-window");
const userInput = document.getElementById("user-input");
const sendBtn = document.getElementById("send-btn");

// Function to append messages to the chat window
function appendMessage(content, className) {
  const messageDiv = document.createElement("div");
  messageDiv.className = `message ${className}`;
  messageDiv.textContent = content;
  chatWindow.appendChild(messageDiv);
  chatWindow.scrollTop = chatWindow.scrollHeight;
}

// Function to send the user's message to the server
async function sendMessage() {
  const message = userInput.value.trim();
  if (!message) return;

  console.log("message", message);
  appendMessage(message, "user");
  userInput.value = "";

  try {
    const response = await fetch("http://localhost:3000/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ message }),
    });
    console.log("response", response);
    const data = await response.json();
    if (data.reply) {
      appendMessage(data.reply, "bot");
    } else {
      appendMessage("Error: Unable to get a response from the chatbot.", "bot");
    }
  } catch (error) {
    console.error(error);
    appendMessage("Error: Something went wrong.", "bot");
  }
}

// Event listener for the send button
sendBtn.addEventListener("click", sendMessage);

// Event listener for Enter key
userInput.addEventListener("keypress", (event) => {
  if (event.key === "Enter") {
    sendMessage();
  }
});
