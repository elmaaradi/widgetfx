/*
 * WidgetFX - JavaFX Desktop Widget Platform
 * Copyright (C) 2008  Stephen Chin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package org.widgetfx.config;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.util.Properties;

/**
 * @author Stephen Chin
 * @author Keith Combs
 */
public class ConfigPersister {
    public attribute configuration:Configuration;
    
    public attribute file:File;
    
    public attribute autoSave = false;
    
    private function changeListener(changedProperty:Property):Void {
        if (autoSave) {
            save();
        }
    }
    
    public attribute properties = bind if (configuration == null) null else configuration.properties on replace [i..j]=newProperties {
        for (property in newProperties) {
            property.onChange = changeListener;
        }
    }
    
    public function load() {
        var previousAutoSave = autoSave;
        autoSave = false;
        try {
            if (file.exists() and configuration.properties != null) {
                var savedProperties = Properties {};
                var reader = new FileReader(file);
                try {
                    savedProperties.load(reader);
                } finally {
                    reader.close();
                }
                for (property in configuration.properties) {
                    if (savedProperties.containsKey(property.name)) {
                        property.setStringValue(savedProperties.get(property.name) as String);
                    }
                }
            }
        } finally {
            autoSave = previousAutoSave;
        }
        if (configuration.onLoad != null) {
            configuration.onLoad();
        }
    }
    
    public function save() {
        if (configuration.properties != null) {
            var savedProperties = Properties {};
            for (property in configuration.properties) {
                savedProperties.put(property.name, property.getStringValue());
            }
            file.getParentFile().mkdirs();
            file.createNewFile();
            var writer = new FileWriter(file);
            try {
                savedProperties.store(writer, null);
            } finally {
                writer.close();
            }
        }
        if (configuration.onSave != null) {
            configuration.onSave();
        }
    }
}
