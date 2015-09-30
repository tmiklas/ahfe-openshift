# ahfe-openshift
Ad Hoc File Exchange for OpenShift

This is a simple file uplaod/downlaod script that can be hosted on RedHat's OpenShift. It doesn't differ much from other similar scripts, except for default expiry of uploaded files and the fact that you can trivially deploy it on OpenShift.

The script is written in Perl using [Mojolicious::Lite](http://mojolicio.us/) MVC. It is pretty usable as-is and delivered as such - user at your own risk.

**Ideas for the future:**

* Option to expire files after N downloads instead of time
* Simple, non-radmon, user derived directories in download path (has some valid use scenarios)
* Startup scripts to operate standalone version if not deployed on OpenShift

That's all for now folks!
Enjoy :-)