jQuery(function(_) {
  window.stomp = new STOMPClient();
    
  var client_id = JSON.stringify({
    time: (new Date()).toString(),
    user_agent: navigator.userAgent
  });
  
  stomp.onopen = function() {
    console.log("Opened Stomp Transport");
  };
  
  stomp.onclose = function() {
    console.log("Closed Stomp Transport");
    console.log("Reconnecting");
    connect();
  };
  
  stomp.onerror = function(error) {
    console.error(error);
  };
  
  stomp.onerrorframe = function(frame) {
    console.error('Error Frame: ', frame.body);
  };
  
  stomp.onconnectedframe = function(frame) {
    console.log('Connected Frame: ', frame.body);
    console.log("Subscribing")
    stomp.subscribe('$TRACKS_CRUD', {exchange:''});
  };
  
  stomp.onmessageframe = function(frame) {
    var payload = JSON.parse(frame.body);
    console.log('Message Frame: ', payload);
  };
  
  function connect() {
    console.log("Connecting");
    stomp.connect(document.domain, 61613, client_id, '');
  }
  connect();
});
