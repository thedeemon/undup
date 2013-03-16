module main;
import std.stdio, scans, dfl.application, dfl.messagebox;

void main(string[] argv)
{
	Application.enableVisualStyles();
	Application.autoCollect = false;
	Application.run(new Scans());
}
