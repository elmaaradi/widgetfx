/*
 * WidgetFX - JavaFX Desktop Widget Platform
 * Copyright (c) 2008-2009, WidgetFX Group
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. Neither the name of WidgetFX nor the names of its contributors may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
package org.widgetfx.ui;

import org.widgetfx.*;
import org.widgetfx.config.*;
import org.widgetfx.toolbar.*;
import org.widgetfx.widgets.*;
import org.jfxtras.stage.*;
import java.awt.event.*;
import javafx.animation.*;
import javafx.geometry.*;
import javafx.lang.*;
import javafx.scene.*;
import javafx.scene.effect.*;
import javafx.scene.input.*;
import javafx.scene.input.MouseEvent;
import javafx.scene.paint.*;
import javafx.scene.shape.*;
import javafx.stage.*;
import javax.swing.*;

import java.awt.AWTEvent;
import java.awt.Toolkit;

import java.awt.Component;

import javafx.scene.control.Slider;

/**
 * @author Stephen Chin
 */
public var BORDER = 5;
public var RESIZABLE_TOOLBAR_HEIGHT = 18;
public var NONRESIZABLE_TOOLBAR_HEIGHT = RESIZABLE_TOOLBAR_HEIGHT - BORDER;
public var DS_RADIUS = 5;

public class WidgetFrame extends XDialog, DragContainer {
    var toolbarHeight = bind if (instance.widget.configuration == null) NONRESIZABLE_TOOLBAR_HEIGHT else RESIZABLE_TOOLBAR_HEIGHT;
    
    public-init var hidden = false;
    
    var isFlash = bind widget instanceof FlashWidget;
    
    var useOpacity = bind WidgetFXConfiguration.TRANSPARENT and isFlash and WidgetFXConfiguration.IS_VISTA;
    
    var sliderEnabled = bind style == StageStyle.TRANSPARENT or useOpacity;
    
    var xSync = bind x on replace {
        instance.undockedX = x;
    }
    
    var ySync = bind y on replace {
        instance.undockedY = y;
    }
    
    var widgetWidth = bind widget.width + BORDER * 2 + 1 on replace {
        width = widgetWidth;
        updateFlashBounds();
    }
    
    var boxHeight = bind widget.height + BORDER * 2 + 1;
    
    var widgetHeight = bind boxHeight + toolbarHeight on replace {
        height = widgetHeight;
        updateFlashBounds();
    }
    
    override var independentFocus = true;
    
    public var resizing:Boolean;
    var changingOpacity:Boolean;
    
    var initialWidth:Number;
    var initialHeight:Number;

    var updating = false;

    var originalOpacity = bind instance.opacity on replace {
        if (not updating) {
            updating = true;
            offsetOpacity = originalOpacity - 20;
            updating = false;
        }
    }

    // hack to work around  RT-4905: Slider value not correct when min != 0
    var offsetOpacity:Number on replace {
        if (not updating) {
            updating = true;
            instance.opacity = offsetOpacity + 20;
            updating = false;
        }
    }
        
    var saveInitialPos = function(e:MouseEvent):Void {
        initialX = x;
        initialY = y;
        initialWidth = widget.width;
        initialHeight = widget.height;
        initialScreenX = e.sceneX + x;
        initialScreenY = e.sceneY + y;
    }
    
    function mouseDelta(deltaFunction:function(a:Integer, b:Integer):Void):function(c:MouseEvent):Void {
        return function (e:MouseEvent):Void {
            var xDelta = e.screenX - initialScreenX;
            var yDelta = e.screenY - initialScreenY;
            deltaFunction(xDelta, yDelta);
        }
    }
    
    var startResizing = function(e:MouseEvent):Void {
        resizing = true;
        saveInitialPos(e);
    }
    
    var doneResizing = function(e:MouseEvent):Void {
        if (widget.onResize != null) {
            widget.onResize(widget.width, widget.height);
        }
        instance.saveWithoutNotification();
        resizing = false;
    }
    
    override var title = instance.title;
    
    public function dock(container:WidgetContainer, dockX:Integer, dockY:Integer):Void {
        docking = true;
        Timeline {
            keyFrames: KeyFrame {time: 300ms,
                values: [
                    x => dockX - BORDER tween Interpolator.EASEIN,
                    y => dockY - BORDER - toolbarHeight tween Interpolator.EASEIN
                ],
                action: function() {
                    container.dockAfterHover(instance);
                    if (instance.widget.onResize != null) {
                        instance.widget.onResize(widget.width, widget.height);
                    }
                }
            }
        }.play();
    }
    
    function resize(widthDelta:Number, heightDelta:Number, updateX:Boolean, updateY:Boolean, widthOnly:Boolean, heightOnly:Boolean) {
        var newWidth = if (initialWidth + widthDelta < WidgetInstance.MIN_WIDTH) then WidgetInstance.MIN_WIDTH else initialWidth + widthDelta;
        var newHeight = if (initialHeight + heightDelta < WidgetInstance.MIN_HEIGHT) then WidgetInstance.MIN_HEIGHT else initialHeight + heightDelta;
        if (widget.aspectRatio != 0) {
            var aspectHeight = (newWidth / widget.aspectRatio).intValue();
            var aspectWidth = (newHeight * widget.aspectRatio).intValue();
            newWidth = if (not widthOnly and (heightOnly or aspectWidth < newWidth)) aspectWidth else newWidth;
            newHeight = if (not heightOnly and (widthOnly or aspectHeight < newHeight)) aspectHeight else newHeight;
        }
        if (updateX) {
            x = initialX + initialWidth - newWidth;
        }
        if (updateY) {
            y = initialY + initialHeight - newHeight;
        }
        instance.setWidth(newWidth);
        instance.setHeight(newHeight);
    }
    
    override var opacity = bind (if (hoverContainer) 0.4 else 1) * (if (useOpacity) instance.opacity / 100.0 else 1.0);

    var rolloverOpacity = 0.0;
    var rolloverTimeline = Timeline {
        keyFrames: [
            at (0s) {rolloverOpacity => 0.0}
            at (500ms) {rolloverOpacity => 1.0 tween Interpolator.EASEIN}
        ]
    }
    
    var sceneContents:Group;
    
    var widgetHover = false;
	
    var flashHover = bind if (isFlash) then (widget as FlashWidget).widgetHovering else false;

    var draggingFrame = false;
    
    var hovering = bind widgetHover or flashHover or dragging or draggingFrame on replace {
        FX.deferAction(
            function():Void {
                var newRate = if (hovering) 1 else -1;
                if (rolloverTimeline.rate != newRate) {
                    rolloverTimeline.rate = newRate;
                    rolloverTimeline.play();
                }
            }
        )
    }

    var awtListener = AWTEventListener {
        override function eventDispatched(event:AWTEvent):Void {
            if (event.getSource() instanceof Component and not SwingUtilities.isDescendingFrom(event.getSource() as Component, dialog)) {
                return;
            }
            if (event.getID() == java.awt.event.MouseEvent.MOUSE_ENTERED) {
                widgetHover = true;
            } else if (event.getID() == java.awt.event.MouseEvent.MOUSE_EXITED) {
                widgetHover = false;
            } else if (event.getID() == java.awt.event.MouseEvent.MOUSE_PRESSED) {
                draggingFrame = true;
            } else if (event.getID() == java.awt.event.MouseEvent.MOUSE_RELEASED) {
                draggingFrame = false;
            }
        }
    }
    
    init {
        var dragRect:Group = Group {
            def backgroundColor = bind Color.rgb(0x00, 0x00, 0x00, instance.opacity / 100 * 0.6);
            translateY: toolbarHeight,
            content: [
                Rectangle { // background
                    translateX: BORDER, translateY: BORDER
                    width: bind width - BORDER * 2, height: bind boxHeight - BORDER * 2
                    fill: bind backgroundColor
                },
                if (instance.widget.resizable) then [
                    Rectangle { // NW resize corner
                        width: BORDER, height: BORDER
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.NW_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(-xDelta, -yDelta, true, true, false, false);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // N resize corner
                        translateX: BORDER, width: bind width - BORDER * 2, height: BORDER
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.N_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(0, -yDelta, false, true, false, true);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // NE resize corner
                        translateX: bind width - BORDER, width: BORDER, height: BORDER
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.NE_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(xDelta, -yDelta, false, true, false, false);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // E resize corner
                        translateX: bind width - BORDER, translateY: BORDER
                        width: BORDER, height: bind boxHeight - BORDER * 2
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.E_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(xDelta, 0, false, false, true, false);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // SE resize corner
                        translateX: bind width - BORDER, translateY: bind boxHeight - BORDER
                        width: BORDER, height: BORDER
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.SE_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(xDelta, yDelta, false, false, false, false);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // S resize corner
                        translateX: BORDER, translateY: bind boxHeight - BORDER
                        width: bind width - BORDER * 2, height: BORDER
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.S_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(0, yDelta, false, false, false, true);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // SW resize corner
                        translateY: bind boxHeight - BORDER, width: BORDER, height: BORDER
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.SW_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(-xDelta, yDelta, true, false, false, false);
                        })
                        onMouseReleased: doneResizing
                    },
                    Rectangle { // W resize corner
                        translateY: BORDER, width: BORDER, height: bind boxHeight - BORDER * 2
                        stroke: null, fill: bind backgroundColor
                        cursor: Cursor.W_RESIZE
                        onMousePressed: startResizing
                        onMouseDragged: mouseDelta(function(xDelta:Integer, yDelta:Integer):Void {
                            resize(-xDelta, 0, true, false, true, false);
                        })
                        onMouseReleased: doneResizing
                    }
                ] else [],
                Rectangle { // outer border
                    width: bind width - 1, height: bind boxHeight - 1
                    stroke: Color.BLACK
                    fill: null
                },
                Rectangle { // inner border
                    translateX: 1, translateY: 1
                    width: bind width - 3, height: bind boxHeight - 3
                    stroke: Color.WHITESMOKE
                    fill: null
                }
            ]
            opacity: bind if (widget.resizable) rolloverOpacity * 0.8 else 0.0;
            onMousePressed: function(e:MouseEvent) {
                if (e.button == MouseButton.PRIMARY and not resizing) {
                    prepareDrag(e.x, e.y, e.screenX, e.screenY);
                }
            }
            onMouseDragged: function(e:MouseEvent) {
                doDrag(e.screenX, e.screenY);
            }
            onMouseReleased: function(e:MouseEvent) {
                if (e.button == MouseButton.PRIMARY) {
                    finishDrag(e.screenX, e.screenY);
                }
            }
        }
        var slider = Slider {
            min : 0
            max : 80
            value : bind offsetOpacity with inverse
            clickToPosition: true
            width: bind width * 2 / 5
            onMousePressed : function(e:MouseEvent) {
              changingOpacity = true;
            }
            onMouseReleased : function(e:MouseEvent){
                // todo - this doesn't complete work due to RT-4906: Slider's thumb: no calls of onMouse-functions.
                changingOpacity = false;
                instance.saveWithoutNotification();
            }
        }
        var clip = widget.clip;
        widget.clip = null;
        if (widget.parent instanceof Group) {
            delete widget from (widget.parent as Group).content;
        }
        scene = Scene {
            stylesheets: bind WidgetManager.getInstance().stylesheets
            content: sceneContents = Group {
                var toolbar:WidgetToolbar;
                content: [
                    dragRect,
                    Group { // Widget
                        translateX: BORDER, translateY: BORDER + toolbarHeight
                        cache: true
                        content: Group { // Alert
                            effect: bind if (widget.alert) DropShadow {color: Color.RED, radius: 12, blurType: BlurType.ONE_PASS_BOX} else null
                            content: bind [
                                if (clip != null) { // Clip Shadow (for performance)
                                    Group {
                                        cache: true
                                        effect: bind if (resizing or animating) null else DropShadow {offsetX: 2, offsetY: 2, radius: DS_RADIUS, blurType: BlurType.ONE_PASS_BOX}
                                        content: clip
                                    }
                                } else [],
                                Group { // Drop Shadow
                                    effect: bind if (resizing or animating or widget.clip != null) null else DropShadow {offsetX: 2, offsetY: 2, radius: DS_RADIUS, blurType: BlurType.ONE_PASS_BOX}
                                    content: Group { // Clip Group
                                        content: widget
                                        clip: Rectangle {width: bind widget.width, height: bind widget.height, smooth: false}
                                    }
                                }
                            ]
                        }
                        opacity: bind instance.opacity / 100
                    },
                    if (sliderEnabled) {
                        Group { // Transparency Slider
                            content: [
                                Rectangle { // Border
                                    width: bind width * 2 / 5 + 10
                                    height: 16
                                    arcWidth: 16
                                    arcHeight: 16
                                    stroke: Color.BLACK
                                },
                                Rectangle { // Background
                                    translateX: 1
                                    translateY: 1
                                    width: bind width * 2 / 5 + 8
                                    height: 14
                                    arcWidth: 14
                                    arcHeight: 14
                                    stroke: Color.WHITE
                                    fill: WidgetToolbar.BACKGROUND
                                    opacity: 0.7
                                },
                                Group { // Slider
                                    translateX: 5
                                    translateY: 2
                                    content: slider
                                }
                            ]
                            opacity: bind rolloverOpacity
                        }
                    } else {
                        []
                    },
                    toolbar = WidgetToolbar {
                        translateX: bind width - toolbar.boundsInLocal.maxX
                        opacity: bind rolloverOpacity
                        instance: instance
                        onClose: function() {
                            WidgetManager.getInstance().removeWidget(instance);
                            close();
        		    Toolkit.getDefaultToolkit().removeAWTEventListener(awtListener);
                        }
                    }
                ]
            }
            fill: null
        }
        Toolkit.getDefaultToolkit().addAWTEventListener(awtListener, AWTEvent.MOUSE_EVENT_MASK);
        addFlash();
    }

    override function dragComplete(dragListener:WidgetDragListener, targetBounds:Rectangle2D):Void {
        if (targetBounds != null) {
            dock(dragListener as WidgetContainer, targetBounds.minX + (targetBounds.width - widget.width) / 2, targetBounds.minY);
        }
    }
    
    var flashPanel:JPanel;
    
    public function addFlash() {
        if (isFlash) {
            var flash = widget as FlashWidget;
            flashPanel = flash.createPlayer();
            var layeredPane = (dialog as RootPaneContainer).getLayeredPane();
            layeredPane.add(flashPanel, new java.lang.Integer(1000));
            updateFlashBounds();
            flash.dragContainer = this;
        }
    }
    
    function updateFlashBounds() {
        if (flashPanel != null) {
            var layeredPane = (dialog as RootPaneContainer).getLayeredPane();
            if (flashPanel.getParent() == layeredPane) {
                flashPanel.setBounds(BORDER, BORDER + toolbarHeight, widget.width, widget.height);
            }
        }
    }
}
