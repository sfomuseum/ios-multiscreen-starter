function logMessage(msg){

    if (! isWebkit()){    
        console.log(msg);
        return;
    }

    webkit.messageHandlers.consoleLog.postMessage(JSON.stringify(msg));
}

function debugMessage(msg){
    var debug_el = document.getElementById("debug");
    if (debug_el){
        var dt = new Date();
        var item = document.createElement("li");
        item.setAttribute("data-timestamp", dt.toISOString());
        item.appendChild(document.createTextNode(msg));
        debug_el.prepend(item);
    }
}

function sendMessage(msg){
    
    if (! isWebkit()){
        console.log(msg);
        return;
    }

    webkit.messageHandlers.sendMessage.postMessage(JSON.stringify(msg));
}

function isWebkit() {
    return (typeof(webkit) == "undefined") ? false : true;
}

function setControllerURL(url){
    document.body.setAttribute("data-controller-url", url);
}
