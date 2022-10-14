function initializeReceiverMain(){

    var messages_el = document.getElementById("messages");
    
    var debug_el = document.getElementById("messages");
    
    var debug = function(msg){
        var item = document.createElement("li");
	item.appendChild(document.createTextNode(msg));
        debug_el.appendChild(item);
    }

    var root_url = document.body.getAttribute("data-controller-url");
    var code_url = root_url + "/code/";
    
    // Fetch the most recent access code to display

    setTimeout(function(){

	var on_load = function(rsp){
	    // 
	};
	
	var req = new XMLHttpRequest();
	
	req.addEventListener("load", on_load);
	req.open("GET", code_url, true);
	req.send();
	
    }, 500);
}
