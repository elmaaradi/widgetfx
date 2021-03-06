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
package org.widgetfx.widget.slideshow;

import org.widgetfx.*;
import org.widgetfx.config.*;
import org.jfxtras.async.*;
import org.jfxtras.scene.layout.*;
import org.jfxtras.scene.layout.XGridLayoutInfo.*;
import org.jfxtras.scene.control.XShelf;
import javafx.ext.swing.*;
import javafx.scene.*;
import javafx.scene.control.*;
import javafx.scene.shape.*;
import javafx.scene.paint.*;
import javafx.scene.image.*;
import javafx.scene.text.*;
import javafx.util.*;
import javafx.animation.*;
import javafx.lang.*;
import javax.imageio.*;
import java.io.*;
import java.lang.*;
import javax.swing.*;




import javafx.scene.layout.LayoutInfo;

import javafx.scene.layout.Stack;

/**
 * @author Stephen Chin
 * @author Keith Combs
 */
public class SlideShow extends Widget {
    var home = System.getProperty("user.home");
    var defaultDirectories:File[] = [
        new File(home, "Pictures"),
        new File(home, "My Documents\\My Pictures"),
        new File(home)
    ][d|d.exists()];
    var directoryName:String;
    var directory:File;
    var status = "Loading Images...";
    var imageFiles:String[];
    var shuffle = true;
    var duration:Integer = 10;
    var filter : String;
    var imageIndex:Integer;
    var currentFile:String;
    var index:Integer;
    var nextImage:Image;
    var worker:XWorker;
    var timeline:Timeline;
    var tabbedPane:JTabbedPane;
    var maxFiles = 10000;
    var maxFolders = 1000;
    var folderCount = 0;
    var fileCount = 0;
    var scale:Number = 1;
    var showReflections = false;

    var zoomTimeline = Timeline {
        keyFrames: [
            at (0s) {scale => 1}
            at (1s) {scale => .6 tween Interpolator.SPLINE(.05, .5, .5, .95)}
        ]
    }

    var shelfLayoutInfo = LayoutInfo {
        height: bind height * scale
    }

    override var onMouseEntered = function(e) {
        showReflections = true;
        zoomTimeline.rate = 1;
        zoomTimeline.play();
    }

    override var onMouseExited = function(e) {
        showReflections = false;
        zoomTimeline.rate = -1;
        zoomTimeline.play();
    }

    function initTimeline() {
        imageIndex = 0;
        timeline = Timeline {
            repeatCount: Timeline.INDEFINITE
            keyFrames: [
                KeyFrame {time: 1s * duration,
                    action: function() {
                        index++;
                    }
                }
            ]
        }
    }

    function loadDirectory() {
        var directory = new File(directoryName);
        timeline.stop();
        if (worker != null) {
            worker.cancel();
        }
        if (not directory.exists()) {
            status = "Directory Doesn't Exist";
        } else if (not directory.isDirectory()) {
            status = "Selected File is Not a Directory";
        } else {
            status = "Loading Images...";
            folderCount = 0;
            fileCount = 0;
            imageFiles = getImageFiles(directory);
            if (fileCount > maxFiles) {
                println("Slide Show exceeded limit of {maxFiles} image files.");
            }
            if (folderCount > maxFolders) {
                println("Slide Show exceeded limit of {maxFolders} folders to scan.");
            }
            if (imageFiles.size() > 0) {
                if (shuffle) {
                    imageFiles = Sequences.shuffle(imageFiles) as String[];
                }
                initTimeline();
                timeline.play();
                shelf = XShelf {
                    layoutInfo: shelfLayoutInfo
                    index: bind index with inverse
                    blocksMouse: false
                    imageUrls: bind imageFiles
                    placeholder:Image{url:"{__DIR__}placeholder.png", preserveRatio: true}
                    thumbnailHeight: bind height
                    thumbnailWidth: bind width
                    showScrollBar: false
                    centerGap: 0.5
                    showText: false
                    aspectRatio: aspectRatio
                    reflection:bind showReflections
                    wrap: true
                }
                status = "";
            } else {
                status = "No Images Found"
            }
        }
    }

    function excludesFile(name:String):Boolean {
        if (filter != null and filter.length() > 0) {
            if (name.toLowerCase().contains(filter.toLowerCase())) {
                return true;
            }
        }
        return false;
    }

    function getImageFiles(directory:File):String[] {
        var emptyFile:String[] = [];
        if (folderCount++ >= maxFolders or fileCount >= maxFiles) {
            return emptyFile;
        }
        var fileArray = directory.listFiles();
        if (fileArray == null) {
            return emptyFile;
        }
        var files = java.util.Arrays.asList(fileArray);
        return for (file in files) {
            var name = file.getName();
            if (excludesFile(name)) {
                emptyFile;
            } else {
                var index = name.lastIndexOf('.');
                var extension = if (index == -1) null else name.substring(index + 1);
                if (file.isDirectory()) {
                    getImageFiles(file);
                } else if (extension != null and ImageIO.getImageReadersBySuffix(extension).hasNext()) {
                    fileCount++;
                    var url = file.toURL();
                    var uri = new java.net.URI(url.getProtocol(), url.getUserInfo(),
                        url.getHost(), url.getPort(), url.getPath(), url.getQuery(), url.getRef());
                    [uri.toString().replaceAll("#", "%23")];
                } else {
                    emptyFile;
                }
            }
        }
    }

    var browseButton:SwingButton;

    function setDefaultDirectory() {
        directoryName = defaultDirectories[0].getAbsolutePath();
    }

    var durationSpinner:JSpinner;

    function getConfigUI() {
        var directoryLabel = Text {content: "Directory:"};
        var directoryEdit = TextBox {text: bind directoryName with inverse, columns: 40};
        var keywordLabel = Text {content: "Filter:"};
        var keywordEdit = TextBox {text: bind filter with inverse, columns: 40, layoutInfo: XGridLayoutInfo {hspan: 2}};
        var durationLabel = Text {content: "Duration"};
        var shuffleCheckBox = CheckBox {text: "Shuffle", selected: bind shuffle with inverse};

        // do this after TextBox is created to work around a JavaFX initialization bug
        setDefaultDirectory();

        // todo - replace with javafx spinner when one exists
        durationSpinner = new JSpinner(new SpinnerNumberModel(duration, 2, 60, 1));
        var durationSpinnerComponent = SwingComponent.wrap(durationSpinner);
        durationSpinnerComponent.layoutInfo = XGridLayoutInfo {width: 52, hpos: LEFT}

        browseButton = SwingButton {
            text: "Browse...";
            action: function() {
                var chooser:JFileChooser = new JFileChooser(directoryName);
                chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
                var returnVal = chooser.showOpenDialog(browseButton.getJButton());
                if (returnVal == JFileChooser.APPROVE_OPTION) {
                    directoryName = chooser.getSelectedFile().getAbsolutePath();
                }
            }
        }

        XGrid {
            rows: [
                row([directoryLabel, directoryEdit, browseButton]),
                row([keywordLabel, keywordEdit]),
                row([durationLabel, durationSpinnerComponent]),
                row([shuffleCheckBox])
            ]
        }
    }

    var shelf:XShelf;

    init {
        var view:ImageView;
        content = [
            Stack {
                width: bind width
                height: bind height
                content: bind shelf
            }
            Group {
                var text:Text;
                content: [
                    Rectangle {
                        width: bind width
                        height: bind height
                        fill: Color.BLACK
                        arcWidth: 8, arcHeight: 8
                    },
                    text = Text {
                        translateY: bind height / 2
                        translateX: bind (width - text.boundsInLocal.width) / 2
                        content: bind status
                        fill: Color.WHITE
                    }
                ]
                opacity: bind if (status.length() == 0) 0 else 1;
            }
        ];

        configuration = Configuration {
            properties: [
                StringProperty {
                    name: "directoryName"
                    value: bind directoryName with inverse
                },
                BooleanProperty {
                    name: "shuffle"
                    value: bind shuffle with inverse
                },
                IntegerProperty {
                    name: "duration"
                    value: bind duration with inverse
                },
                StringProperty {
                    name : "keywords"
                    value : bind filter with inverse
                },
                IntegerProperty {
                    name: "maxFiles"
                    value: bind maxFiles with inverse
                },
                IntegerProperty {
                    name: "maxFolders"
                    value: bind maxFolders with inverse
                }
            ]
            scene: Scene {
                content: getConfigUI()
            }

            onLoad: function() {
                // make sure the spinner value is set, since this is not bound:
                durationSpinner.setValue(duration);
                loadDirectory();
            }
            onSave: function() {
                // make sure the duration value is set, since this is not bound:
                durationSpinner.commitEdit();
                duration = durationSpinner.getValue() as Integer;
                loadDirectory();
            }
        }
    }
}
