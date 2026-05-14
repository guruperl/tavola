class Genelet {
  constructor(args) {
	if (args["json"]  ===undefined) args["json"]   = "json";
	if (args["logins"]===undefined) args["logins"] = "login";
	if (args["header"]===undefined) args["header"] = "header";
	if (args["footer"]===undefined) args["footer"] = "footer";
    this.handler= args.handler;
    this.json   = args.json;
    this.logins = args.logins;
    this.header = args.header;
    this.footer = args.footer;
    this.mime   = args.mime;
    this.single = {};
    this.names  = [];
    this.note   = "";
    this.OTHER  = {};
	this.role   = args.role; // default role
	this.comp   = args.comp; // default comp
	this.action = args.action; // default action
    this.partial_header = args.role+"/"+args.header+"."+args.mime;
    this.partial        = args.role+"/"+args.logins+"."+args.mime;
    this.partial_footer = args.role+"/"+args.footer+"."+args.mime;
  }
 
  updateParameters(role, comp, action) {
	this.role   = role;
	this.comp   = comp;
	this.action = action;
    this.partial_header = role+"/"+this.header+"."+this.mime;
    if (action===undefined) this.partial = role+"/"+comp+"."+this.mime;
    else  this.partial = role+"/"+comp+"/"+action+"."+this.mime;
    this.partial_footer = role+"/"+this.footer+"."+this.mime;
  };

  start() {
	var role   = this.role;
	var comp   = this.comp;
	var action = this.action;

    var q = {};
    if (location.hash && location.hash.length>1) {
      var parts = location.hash.substring(1).split("/");
      role = parts[1];
      var arr = parts[2].split("?");
      comp = arr[0];
      var pairs = arr[1].split("&");
      for (var i in pairs) {
        if (pairs[i]==="") continue;
        var pair = pairs[i].split("=");
        q[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
      }
      if (q["action"]===undefined) q["action"] = "topics"; //Request Method
    } else {
      q["action"] = action;
    }
    this.ajaxPage(role, comp, q, "GET");
  };

  processData(role, comp, query, data, method, landing) {
console.log("returned:")
console.log(data)
    var a = "data";
    if (landing===undefined) {
      this.names = data;
      if (data[a]) this.single = data[a][0];
      var search = "";
      if (method==='GET') {
        search = "?" + Object.keys(query).map((key) => { return encodeURIComponent(key) + '=' + encodeURIComponent(query[key]) }).join('&');
      }
      this.updateParameters(role, comp, query.action);
      parent.location.hash = "/"+role+"/"+comp+search;
console.log("Done. PATH: "+"/"+role+"/"+comp+search);
      return true;
    }

    switch (typeof landing) {
    case "boolean":
      if (landing===true) {
        if (data[a]) this.single = data[a][0];
        this.names = data;
      } else {
        this.OTHER[this.note] = data;
      }
console.log("Same partial and url. Done.");
      return true;
    case "function":
      landing(data);
console.log("function assignment.");
      return true;
    case "string":
      if (data[a]) this.single = data[a][0];
      this.OTHER[landing] = data;
console.log("Jump modal: "+landing);
      return true;
    case "object":
      if (landing.operator) {
        var single = data[a][0];
        var lists = this.names[a];
        if (landing.target) {
          var a = landing.target.split('.');
          if (a.length==4) {
            var pos = this.OTHER[a[0]][a[1]].map(function(e) {return e[a[2]];}).indexOf(data[a[2]]);
            if (pos < 0) return false;
            lists = this.OTHER[a[0]][a[1]][pos][a[3]];
            if (lists===undefined) {
              this.OTHER[a[0]][a[1]][pos][a[3]]=[];
              lists = this.OTHER[a[0]][a[1]][pos][a[3]];
            }
          }
          if (a.length==3) {
            var s = this.names[this.names.action][0][a[0]];
            var pos=s.map(function(e) {return e[a[1]];}).indexOf(data[a[1]]);
            if (pos < 0) return false;
            lists = s[pos][a[2]];
            if (lists===undefined) {
              s[pos][a[2]]=[];
              lists = s[pos][a[2]];
            }
          }
          if (a.length==2) lists = this.OTHER[a[0]][a[1]];
          if (a.length==1) lists = this.OTHER[a[0]];
        }
        if (single===undefined || lists===undefined) return false;
        if (landing.operator==='insert') {
          if (landing.extra) landing.extra.forEach((v,k)=>{ single[k]=v; });
          lists.push(single);
        } else {
/* the following is an ugly fix because PDO returns integer as string in some driver 
          var pos = lists.map(function(e) {return e[landing.id_name];}).indexOf(single[landing.id_name]);
*/
          var pos = -1;
          for (var i = 0; i < lists.length; i++) {
            var x = single[landing.id_name];
            var y = lists[i][landing.id_name];
            if ((typeof(x)==="string" && typeof(y)==="number" && parseInt(x) == y) || (x==y)) {
              pos = i;
              break;
            }
          }
/* finish the ugly fix */
          if (pos < 0) return false;
          if (landing.operator==='delete') {
            lists.splice(pos,1);
          } else if (landing.operator==='update') {
            for (var k in single) {
              if (single[k]) lists[pos][k] = single[k];
            }
          }
        }
console.log("Stay on this page, and no refresh.");
        return true;                
      } else {
        var s = landing.query || {};
        s.action = landing.action || query.action;
        var r = landing.role || role;
        var c = landing.comp || comp;
console.log("Landing on new role, comp and action: "+r+", "+c+ " and "+s.action);
        return this.ajaxPage(r, c, s, "GET", landing.refresh);
      }
    }
    return false; 
  };

  ajaxPage(role, comp, query, method, landing) {
console.log("start ajax..." + role + ", " + comp);
    var url = this.handler+"/"+role+"/"+this.json+"/"+comp;

    var that = this;
	var xhttp = new XMLHttpRequest()
	xhttp.onreadystatechange = function() {
      if (this.readyState == 4) {
		if (this.status == 401 && this.getResponseHeader("WWW-Authenticate") !== null) {
console.log("Login please.");
          that.names = {"error_code":this.getResponseHeader("Tabilet-Error"), "error_string":this.getResponseHeader("Tabilet-Error-Description")};
          that.updateParameters(role, that.logins);
		} else if (this.status == 400 && comp == that.logins) {
          that.names = {"error_code":this.getResponseHeader("Tabilet-Error"), "error_string":this.getResponseHeader("Tabilet-Error-Description")};
console.log("ReLogin please.");
          that.updateParameters(role, that.logins);
        } else if (this.status == 200) {
console.log("RAW: " + this.responseText);
          var data = JSON.parse(this.responseText);
          if (data.token_type !== null && data.token_type == "bearer") {
console.log("Login successful.");
            that.processData(role, comp, query, data, method, landing);
          } else if (data.success) {
console.log("Normal request.");
            that.processData(role, comp, query, data, method, landing);
          } else {
            window.alert(data.error_string);
          }
        } else {
          window.alert("System error: "+location.href+".."+this.status);
	    }
      }
    };
    if (method===undefined || method==='GET') { 
      var pairs = [];
      for (var k in query) pairs.push(k+"="+encodeURIComponent(query[k]));
      xhttp.open("GET", url+"?"+pairs.join("&"), true);
      xhttp.send();
    } else {
      var pairs = [];
      for (var k in query) pairs.push(k+"="+query[k]);
      xhttp.open("POST", url, true);
      xhttp.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
      xhttp.send(pairs.join("&"));
    }
  };

  go(r, c, a, q, landing) {
    if (q===undefined) q = {};
    q.action = a;
    return this.ajaxPage(r, c, q, "GET", landing);
  };

  send(r, c, a, q, landing) {
    if (q===undefined) q = {};
    q.action = a;
    return this.ajaxPage(r, c, q, "POST", landing);
  };

  login(r, c, a, q, provider) {
    if (provider===undefined) provider = "db";
    q.provider = provider
    return this.ajaxPage(r, this.logins, q, "POST", {role:r, comp:c, action:a});
  };

  api_go(r, c, a, q, name, optional) {
    if (optional && typeof this.OTHER[name]=="object") return;
    if (q===undefined) q = {};
    q.action = a;
    this.note = name;
    return this.ajaxPage(r, c, q, 'GET', false);
  };

  going(name, f, s){
    this.single = {...f, ...s};
  };
};

class VueGenelet extends Genelet {
  constructor(args) {
    super(args);
    this.headerComponent = args.role+"-"+args.header;
    this.currentComponent= args.role+"-"+args.comp+"-"+args.action;
    this.footerComponent = args.role+"-"+args.footer;
  }

  updateParameters(role, comp, action) {
    super.updateParameters(role, comp, action)
    this.headerComponent  = role+"-"+this.header;
    if (action===undefined) this.currentComponent = role+"-"+comp;
    else  this.currentComponent = role+"-"+comp+"-"+action;
    this.footerComponent  = role+"-"+this.footer;
  };
}
