/*
 * Generated by JavaFX Production Suite NetBeans plugin.
 * RallyWidgetUI.fx
 *
 * Created on Thu Nov 12 17:51:28 PST 2009
 */
package rallywidget;

import java.lang.*;
import javafx.scene.Node;
import javafx.fxd.FXDNode;

public class RallyWidgetUI extends FXDNode {
	
	override public var url = "{__DIR__}RallyWidget.fxz";
	
	public-read protected var background: Node;
	public-read protected var border: Node;
	public-read protected var headerBackground: Node;
	public-read protected var rally: Node;
	public-read protected var statusActive: Node;
	public-read protected var statusInactive: Node;
	public-read protected var todoStatusBad: Node;
	public-read protected var todoStatusGood: Node;
	public-read protected var userName: Node;
	
	override protected function contentLoaded() : Void {
		background=getNode("background");
		border=getNode("border");
		headerBackground=getNode("headerBackground");
		rally=getNode("rally");
		statusActive=getNode("statusActive");
		statusInactive=getNode("statusInactive");
		todoStatusBad=getNode("todoStatusBad");
		todoStatusGood=getNode("todoStatusGood");
		userName=getNode("userName");
	}
	
	/**
	 * Check if some element with given id exists and write 
	 * a warning if the element could not be found.
	 * The whole method can be removed if such warning is not required.
	 */
	protected override function getObject( id:String) : Object {
		var obj = super.getObject(id);
		if ( obj == null) {
			System.err.println("WARNING: Element with id {id} not found in {url}");
		}
		return obj;
	}
}

