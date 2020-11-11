function initializeMain(){
    
    var dt = new Date();
    logMessage("Initialize main at " + dt.toString());
    
    var messageCount = 0;

    var button = document.getElementById("send-button");
    
    if (! button){
        logMessage("Unable to find #send-button element.");
        return;
    }
    
    button.onclick = function(){
            
        messageCount += 1;
        
        try {
            sendMessage("Message count is now " + messageCount);
        } catch (err) {
            logMessage("Failled to send message " + err);
        }
    };
}
