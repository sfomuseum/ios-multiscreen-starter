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
        var item = document.createElement("li");
        item.appendChild(document.createTextNode(msg));
        debug_el.appendChild(item);
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
