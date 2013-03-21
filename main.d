module main;
import std.stdio, scans, dfl.application, dfl.messagebox, std.process, std.c.windows.com;

void main(string[] argv)
{
	CoInitialize(null);
	Application.enableVisualStyles();
	Application.autoCollect = false;
	auto sc = new Scans(argv.length > 1 ? argv[1] : "");
	Application.run(sc);
	if (sc.restartString.length > 0) 
		execv(argv[0], [argv[0], sc.restartString]);	
}
