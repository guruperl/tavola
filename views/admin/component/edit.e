[% INCLUDE start.e %]
[% SET item=edit.0 %]

<script>
	$(function() {
		$( "#tabs" ).tabs();
	});

function resize(id,event) {
    var area = document.getElementById(id);
    if(13==event.keyCode) { area.rows = area.value.split("\n").length;}
    if(8==event.keyCode || 46==event.keyCode) {  area.rows = area.value.split("\n").length;}
};

</script>

<form name=f1 action="component" method=post><input type=hidden name=project value="[% project %]" /><input type=hidden name=force value=1 /><input type=hidden name=action value=update /><input type=hidden name=c value="[% c %]">

<h3>Project <a href="project?action=edit&project=[% project FILTER lower %]">[% project FILTER ucfirst %]</a> :: Component <em>[% c FILTER ucfirst %]</em></h3>

<div class="form_settings">

<div id="tabs">
	<ul>
		<li><a href="#tabs-8">Actions</a></li>
		<li><a href="#tabs-6">Custom</a></li>
	</ul>
	<div id="tabs-8">
		<textarea id="action-area" onKeyUp="resize(id,event)" name=cactions cols=85 rows=15>[% item.cactions_str %]</textarea>
<h4>Format:</h4>
<pre>
{
  "NAME" : {"groups" : <em>array</em>, "validate" : <em>array</em>},
  ...
}
</pre>
	</div>
<!--
	<div id="tabs-1">
		<textarea id="action-area" onKeyUp="resize(id,event)" name=actions cols=85 rows=15>[% item.actions_str %]</textarea>
<h4>Format:</h4>
<pre>
{
"startnew" : {"groups" : <em>array</em>, "validate" : <em>array</em>, "no_db" : 1, "no_method" : 1},
  "topics" : {"groups" : <em>array</em>, "validate" : <em>array</em>},
    "edit" : {"groups" : <em>array</em>, "validate" : <em>array</em>},
  "insert" : {"groups" : <em>array</em>, "validate" : <em>array</em>},
  "update" : {"groups" : <em>array</em>, "validate" : <em>array</em>},
  "delete" : {"groups" : <em>array</em>, "validate" : <em>array</em>}
}
</pre>
	</div>
	<div id="tabs-2">
		<textarea id="item-area" onKeyUp="resize(id,event)" name=fks cols=85 rows=4>[% item.fks_str %]</textarea>
<h4>Format</h4>
<pre>
{
<em>role</em> : <em>array[4]</em>,
<em>role</em> : <em>array[4]</em>,
...
}
</pre>
	</div>
	<div id="tabs-3">
		<textarea id="escs-area" onKeyUp="resize(id,event)" name=escs cols=85 rows=2>[% item.escs_str %]</textarea>
<h4>Format</h4>
<pre>
[<em>name</em>, <em>name</em>, ... ]
</pre>
	</div>
	<div id="tabs-4">
		<textarea id="init-area" onKeyUp="resize(id,event)" name=init cols=85 rows=15>[% item.init_str %]</textarea>
<h4>Format</h4>
<pre>
{
"current_key"     : <em>name</em>,
"current_id_auto" : <em>name</em>,
"current_table"   : <em>name</em>,
"current_tables"  : [ 
	{"name" : <em>name</em>, "type" : <em>name</em>, "on" : <em>name</em>},
	{"name" : <em>name</em>, "type" : <em>name</em>, "on" : <em>name</em>},
	...
],
"topics_pars" : [<em>name</em>, <em>name</em>, ... ],
"topics_pars" : {<em>name</em> : <em>name</em>, ... }, -- if "current_tables"
"edit_pars"   : [<em>name</em>, <em>name</em>, ... ],
"insert_pars" : [<em>name</em>, <em>name</em>, ... ],
"update_pars" : [<em>name</em>, <em>name</em>, ... ]
}	
</pre>
	</div>
	<div id="tabs-5">
		<textarea id="filter-area" onKeyUp="resize(id,event)" name=filters cols=85 rows=15>[% item.filters_str %]</textarea>
<h4>Format</h4>
<pre>
{
"preset" : [
	{
	"conditions" : { "role" : <em>name</em>, "action" : <em>name</em>, "in_"<em>par</em> : <em>name</em>},	
	"set" : {"in_"<em>par</em> : <em>value</em>, "append" : [<em>name</em>, <em>name</em>, ...]},
	},
	...
],
"before" : [ 
	{
	"conditions" : { "role" : <em>name</em>, "action" : <em>name</em>, "in_"<em>par</em> : <em>name</em>},	
	"set" : {"sql_"<em>par</em> : "in_"<em>par</em>, "sql_"<em>par</em> : <em>value</em>, "append" : [<em>name</em>, <em>name</em>, ...]},
	},
	...
],
"after" : [
	{
	"conditions" : { "role" : <em>name</em>, "action" : <em>name</em>, "in_"<em>par</em> : <em>name</em>},	
	"set" : {"sql_"<em>par</em> : <em>name</em>, "append" : [<em>name</em>, <em>name</em>, ...]},
	"mail" : {"To" or "Subject" or "Reply_To" or "From" : "in_"<em>par</em> or "sql_"<em>par</em> or <em>name</em>},
	},
	...
]
}

Note:
1) "in_"<em>par</em> means an incoming query variable with the name <em>par</em>;
2) "sql_"<em>par</em> means variable <em>par</em> in the SQL table;
3) <em>value</em> in "set" is one of the following: HTTP_COOKIE, HTTP_HOST, HTTP_REFERE, 
HTTP_USER_AGENT, REMOTE_ADDR, REMOTE_HOST, REMOTE_PORT, REMOTE_USER, int_ip, 
int_time, mysql_now, mysql_curdate, rand_int, rand_str, rand_id
</pre>
	</div>
-->
	<div id="tabs-6">
		<textarea id="custom-area" onKeyUp="resize(id,event)" name=customized cols=85 rows=15>[% item.customized_str %]</textarea>
<h4>Format</h4>
<pre>
{
  "NAME" : {"type" : <em>string</em>, "sql" : <em>string</em>, "pars" : [<em>array</em>, "out_pars" : <em>array</em>},
  ...
}
</pre>
	</div>
<!--
	<div id="tabs-7">
		<textarea id="trigger-area" onKeyUp="resize(id,event)" name=triggers cols=85 rows=15>[% item.triggers_str %]</textarea>
<h4>Format</h4>
<pre>
{
"edit" or "topics" or "insert" or "update" or "delete" : [
	{
	"model"       : <em>name</em>,
	"action"      : <em>name</em>,
	"relate_fk"   : <em>name</em>,
	"relate_item" : {<em>name</em> : <em>name</em>, ...},
	"manual"      : {<em>name</em> : <em>name</em>, ...},
	},
	...
],
...
}
</pre>
	</div>
-->
</div>
</div>

<p style="padding-top: 15px"><span>&nbsp;</span><input class="submit" type=submit value="  Update  " /></p>
</form>

[% IF sql %]<!-- form name=f2 method=post action=component>
<input type=hidden name=action value='runsql' />
<input type=hidden name=project value='[% project %]' />
<input type=hidden name=c value='[% c %]' />
<h3>Insert Data Directly</h3>
<table>
<tr><td>Fields: </td><td><input type=text name=fields size=40 /></td></tr>
<tr><td>Values: </td><td><input type=text name=values size=40 /></td></tr>
<tr><td>        </td><td><input type=submit value="  Run SQL  " />
</table>
</form -->[% END %]

[% INCLUDE end.e %]
