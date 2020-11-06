function logMessage(msg){

    if (! isWebkit()){    
	console.log(msg);
	return;
    }

    webkit.messageHandlers.consoleLog.postMessage(JSON.stringify(msg));
}

function isWebkit() {
    return (typeof(webkit) == "undefined") ? false : true;
}
