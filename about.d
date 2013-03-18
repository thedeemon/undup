module about;
import dfl.all;

class About: dfl.form.Form
{
	// Do not modify or move this block of variables.
	//~Entice Designer variables begin here.
	dfl.label.Label label1;
	dfl.button.Button btnSite;
	dfl.button.Button btnClose;
	//~Entice Designer variables end here.
		
	this()
	{
		initializeAbout();
	}
	
	private void initializeAbout()
	{
		// Do not manually modify this function.
		//~Entice Designer 0.8.5.02 code begins here.
		//~DFL Form
		text = "About Undup";
		clientSize = dfl.all.Size(400, 162);
		//~DFL dfl.label.Label=label1
		label1 = new dfl.label.Label();
		label1.name = "label1";
		label1.text = "Storage space visualization and duplicate search utility.\r\n(C) 2013 Infognition Co. Ltd.";
		label1.textAlign = dfl.all.ContentAlignment.MIDDLE_CENTER;
		label1.bounds = dfl.all.Rect(16, 16, 368, 56);
		label1.parent = this;
		//~DFL dfl.button.Button=btnSite
		btnSite = new dfl.button.Button();
		btnSite.name = "btnSite";
		btnSite.text = "www.infognition.com";
		btnSite.bounds = dfl.all.Rect(112, 88, 176, 24);
		btnSite.parent = this;
		//~DFL dfl.button.Button=btnClose
		btnClose = new dfl.button.Button();
		btnClose.name = "btnClose";
		btnClose.text = "OK";
		btnClose.bounds = dfl.all.Rect(168, 128, 72, 24);
		btnClose.parent = this;
		//~Entice Designer 0.8.5.02 code ends here.

		btnClose.click ~= (Control c, EventArgs a) => close();
		btnSite.click ~= &OnSite;
	}

	void OnSite(Control sender, EventArgs ea)
	{
		import dfl.internal.winapi;
		ShellExecuteA(null, null, "http://www.infognition.com/", null, null, 5);
	}
}

