[% INCLUDE start.e %]
[% SET item=edit.0 %]

<form name=f1 action=project method=post><input type=hidden name=force value=1><input type=hidden name=action value=update>

<h3>Project <em>[% project FILTER ucfirst %]</em></h3>

[% IF components %]Components: &nbsp; [% FOREACH c IN components %]
| [% IF c.disk %]<a href="component?action=edit&project=[% project FILTER lower %]&c=[% c.name FILTER lower %]">[% c.name FILTER ucfirst %]</a>[% ELSE %][% c.name FILTER ucfirst %] (incomplete)[% END %] &nbsp;
[% END %][% END %]

<div class='form_settings'>

<input type=text name=c_string value="[% item.c_string %]" />
<p></p>
<input class="submit" type=submit value='  Update  ' />

</div>

</form>

[% INCLUDE end.e %]
