module legend;
import dfl.all, resizer;

class Legend: dfl.form.Form
{
	// Do not modify or move this block of variables.
	//~Entice Designer variables begin here.
	dfl.textbox.TextBox textBox;
	dfl.button.Button btnClose;
	//~Entice Designer variables end here.
	
	Resizer resizer;

	this()
	{
		initializeLegend();
	}
	
	
	private void initializeLegend()
	{
		// Do not manually modify this function.
		//~Entice Designer 0.8.5.02 code begins here.
		//~DFL Form
		text = "Legend";
		clientSize = dfl.all.Size(520, 394);
		//~DFL dfl.textbox.TextBox=textBox
		textBox = new dfl.textbox.TextBox();
		textBox.name = "textBox";
		textBox.bounds = dfl.all.Rect(16, 16, 488, 344);
		textBox.parent = this;
		textBox.multiline = true;
		textBox.readOnly = true;
		textBox.scrollBars = dfl.all.ScrollBars.VERTICAL;
		//~DFL dfl.button.Button=btnClose
		btnClose = new dfl.button.Button();
		btnClose.name = "btnClose"; 
		btnClose.text = "Close";
		btnClose.bounds = dfl.all.Rect(424, 368, 80, 24);
		btnClose.parent = this;
		//~Entice Designer 0.8.5.02 code ends here.

		showInTaskbar = false;
		textBox.text = import("legend.txt");
		btnClose.click ~= (Control c, EventArgs a) => close();

		resizer = new Resizer(this);
		resizer.let(btnClose, XCoord.moves, YCoord.moves);
		resizer.let(textBox, XCoord.resizes, YCoord.resizes);
		resizer.prepare();

		this.activated ~= (Form frm, EventArgs args) => btnClose.focus();
		this.load ~= (Form f, EventArgs a) => centerToParent(); 
	}

	override void onResize(EventArgs ea) { resizer.go(); }
}

