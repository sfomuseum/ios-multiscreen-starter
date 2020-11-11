function initializeExternal(){
    var dt = new Date();
    logMessage("INITIALIZE EXTERNAL " + dt.toString());
}

function receiveMessage(msg){
    
    var list = document.getElementById("messages");
    
    if (! list){
        logMessage("Unable to load #messages element.");
        return false;
    }
    
    var dt = new Date();
    
    var item = document.createElement("li");
    item.innerText = dt.toString() + " " + msg;
    
    list.prepend(item);
    return true;
}
