module scans;
import dfl.all, newscan;

class Scans: dfl.form.Form
{
	// Do not modify or move this block of variables.
	//~Entice Designer variables begin here.
	dfl.listview.ListView lvScans;
	dfl.button.Button btnNew;
	dfl.button.Button btnShow;
	dfl.button.Button btnRemove;
	dfl.button.Button btnAbout;
	dfl.label.Label label1;
	//~Entice Designer variables end here.
	
	this()
	{
		initializeScans();		
		//@  Other Scans initialization code here.		
	}
	
	
	private void initializeScans()
	{
		// Do not manually modify this function.
		//~Entice Designer 0.8.5.02 code begins here.
		//~DFL Form
		text = "Scans";
		clientSize = dfl.all.Size(784, 618);
		//~DFL dfl.listview.ListView=lvScans
		lvScans = new dfl.listview.ListView();
		lvScans.name = "lvScans";
		lvScans.allowColumnReorder = true;
		lvScans.checkBoxes = true;
		lvScans.fullRowSelect = true;
		lvScans.hideSelection = false;
		lvScans.labelWrap = false;
		lvScans.view = dfl.all.View.DETAILS;
		lvScans.bounds = dfl.all.Rect(8, 40, 768, 520);
		lvScans.parent = this;
		//~DFL dfl.button.Button=btnNew
		btnNew = new dfl.button.Button();
		btnNew.name = "btnNew";
		btnNew.text = "New scan";
		btnNew.bounds = dfl.all.Rect(8, 8, 104, 24);
		btnNew.parent = this;
		//~DFL dfl.button.Button=btnShow
		btnShow = new dfl.button.Button();
		btnShow.name = "btnShow";
		btnShow.text = "Show";
		btnShow.bounds = dfl.all.Rect(152, 8, 104, 24);
		btnShow.parent = this;
		//~DFL dfl.button.Button=btnRemove
		btnRemove = new dfl.button.Button();
		btnRemove.name = "btnRemove";
		btnRemove.text = "Remove";
		btnRemove.bounds = dfl.all.Rect(544, 8, 104, 24);
		btnRemove.parent = this;
		//~DFL dfl.button.Button=btnAbout
		btnAbout = new dfl.button.Button();
		btnAbout.name = "btnAbout";
		btnAbout.text = "?";
		btnAbout.bounds = dfl.all.Rect(752, 8, 24, 24);
		btnAbout.parent = this;
		//~DFL dfl.label.Label=label1
		label1 = new dfl.label.Label();
		label1.name = "label1";
		label1.text = "Scan one or more drives with 'New scan', then select the ones you want to see and compare using Ctrl-Click and press 'Show'. ";
		label1.bounds = dfl.all.Rect(8, 568, 768, 48);
		label1.parent = this;
		//~Entice Designer 0.8.5.02 code ends here.

		btnNew.click ~= &OnNewScan;
	}

	void OnNewScan(Control, EventArgs)
	{
		auto frm = new NewScan();
		frm.showDialog();
	}
}

