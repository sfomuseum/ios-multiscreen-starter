function receiveMessage(raw){

    /*
    var debug_el = document.getElementById("messages");
    var item = document.createElement("li");
    item.appendChild(document.createTextNode("[DEBUG] " + raw));
    debug_el.appendChild(item);
    */
    
    var msg = JSON.parse(raw);
    
    if (msg.type == "update"){
	showMessage(msg.data.body);	
    } else if (msg.type == "showCode"){
	showCode(msg.data.code);
    } else if (msg.type == "hideCode"){
	hideCode();	
    } else {
	console.log("Unhandled message type", msg.type)
    }
}
function initializeReceiverExternal(){

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

function showMessage(msg){
    
    var dt = new Date();
    
    var item = document.createElement("li");
    item.innerText = dt.toLocaleString() + ": " + msg;

    var messages_el = document.getElementById("messages");
    messages_el.prepend(item);
}

function showCode(code){

    var root_url = document.body.getAttribute("data-controller-url");
    var url = root_url + "?code=" + code;
    
    var qr_el = document.getElementById("qr");
    qr_el.innerHTML = "";
    
    var qr_args = {
	height: 150,
	width: 150,
	text: url,
    }
    
    new QRCode(qr_el, qr_args);
    
    qr_el.style.display = "block";
    
    var url_el = document.getElementById("url");
    url_el.setAttribute("href", url);
    url_el.innerText = url;
}

function hideCode(code){

    var qr_el = document.getElementById("qr");	    
    qr_el.innerHTML = "";
    
    qr.style.display = "none";
    
    var url_el = document.getElementById("url");	    
    url_el.innerHTML = "";
    url_el.setAttribute("href", "#");
}
