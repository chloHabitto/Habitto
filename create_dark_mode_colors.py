#!/usr/bin/env python3
import json
import os

# Define all primitive colors with light and dark mode variants
colors = {
    "Yellow": {
        "yellow50": {"light": "#FEF6E6", "dark": "#FEF6E6"},
        "yellow100": {"light": "#FCE2B0", "dark": "#FCE2B0"}, 
        "yellow200": {"light": "#FAD58A", "dark": "#FAD58A"},
        "yellow300": {"light": "#F8C154", "dark": "#F8C154"},
        "yellow400": {"light": "#F7B533", "dark": "#F7B533"},
        "yellow500": {"light": "#F5A300", "dark": "#F5A300"},
        "yellow600": {"light": "#DF9400", "dark": "#DF9400"},
        "yellow700": {"light": "#AE7400", "dark": "#AE7400"},
        "yellow800": {"light": "#875A00", "dark": "#875A00"},
        "yellow900": {"light": "#674400", "dark": "#674400"}
    },
    "Green": {
        "green50": {"light": "#EBF9EE", "dark": "#EBF9EE"},
        "green100": {"light": "#C0EECC", "dark": "#C0EECC"},
        "green200": {"light": "#A2E5B3", "dark": "#A2E5B3"}, 
        "green300": {"light": "#77D990", "dark": "#77D990"},
        "green400": {"light": "#5DD27A", "dark": "#5DD27A"},
        "green500": {"light": "#34C759", "dark": "#34C759"},
        "green600": {"light": "#2FB551", "dark": "#2FB551"},
        "green700": {"light": "#258D3F", "dark": "#258D3F"},
        "green800": {"light": "#1D6D31", "dark": "#1D6D31"},
        "green900": {"light": "#165425", "dark": "#165425"}
    },
    "Red": {
        "red50": {"light": "#FCEBEE", "dark": "#FCEBEE"},
        "red100": {"light": "#F7C0C9", "dark": "#F7C0C9"},
        "red200": {"light": "#F3A2AF", "dark": "#F3A2AF"},
        "red300": {"light": "#EE778A", "dark": "#EE778A"}, 
        "red400": {"light": "#EA5D74", "dark": "#EA5D74"},
        "red500": {"light": "#E53451", "dark": "#E53451"},
        "red600": {"light": "#D02F4A", "dark": "#D02F4A"},
        "red700": {"light": "#A3253A", "dark": "#A3253A"},
        "red800": {"light": "#7E1D2D", "dark": "#7E1D2D"},
        "red900": {"light": "#601622", "dark": "#601622"}
    },
    "Navy": {
        "navy50": {"light": "#E8E9ED", "dark": "#E8E9ED"},
        "navy100": {"light": "#B9BCC8", "dark": "#B9BCC8"},
        "navy200": {"light": "#979CAD", "dark": "#979CAD"},
        "navy300": {"light": "#676E87", "dark": "#676E87"},
        "navy400": {"light": "#495270", "dark": "#495270"}, 
        "navy500": {"light": "#1C274C", "dark": "#1C274C"},
        "navy600": {"light": "#192345", "dark": "#192345"},
        "navy700": {"light": "#141C36", "dark": "#141C36"},
        "navy800": {"light": "#0F152A", "dark": "#0F152A"},
        "navy900": {"light": "#0C1020", "dark": "#0C1020"}
    },
    "PastelBlue": {
        "pastelBlue50": {"light": "#F4F6FF", "dark": "#F4F6FF"},
        "pastelBlue100": {"light": "#EDF1FF", "dark": "#EDF1FF"},
        "pastelBlue300": {"light": "#B3C4FF", "dark": "#B3C4FF"},
        "pastelBlue400": {"light": "#A4B9FF", "dark": "#A4B9FF"},
        "pastelBlue500": {"light": "#8DA7FF", "dark": "#8DA7FF"},
        "pastelBlue600": {"light": "#8098E8", "dark": "#8098E8"},
        "pastelBlue700": {"light": "#6477B5", "dark": "#6477B5"},
        "pastelBlue800": {"light": "#4E5C8C", "dark": "#4E5C8C"},
        "pastelBlue900": {"light": "#3B466B", "dark": "#3B466B"}
    },
    "Grey": {
        "grey50": {"light": "#F9F9F9", "dark": "#F9F9F9"},
        "grey100": {"light": "#ECECEF", "dark": "#ECECEF"},
        "grey200": {"light": "#E3E3E7", "dark": "#E3E3E7"},
        "grey300": {"light": "#D7D7DC", "dark": "#D7D7DC"},
        "grey400": {"light": "#CFCFD5", "dark": "#CFCFD5"},
        "grey500": {"light": "#C3C3CB", "dark": "#C3C3CB"},
        "grey600": {"light": "#B1B1B9", "dark": "#B1B1B9"},
        "grey700": {"light": "#8A8A90", "dark": "#8A8A90"},
        "grey800": {"light": "#6B6B70", "dark": "#6B6B70"},
        "grey900": {"light": "#525255", "dark": "#525255"},
        "greyBlack": {"light": "#191919", "dark": "#191919"},
        "greyWhite": {"light": "#FFFFFF", "dark": "#FFFFFF"}
    }
}

def hex_to_rgb(hex_color):
    """Convert hex color to RGB components"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return r, g, b

def create_color_set_json(color_name, light_hex, dark_hex):
    """Create JSON for a color set with light and dark mode"""
    light_r, light_g, light_b = hex_to_rgb(light_hex)
    dark_r, dark_g, dark_b = hex_to_rgb(dark_hex)
    
    return {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue": f"0x{light_b:02X}",
                        "green": f"0x{light_g:02X}",
                        "red": f"0x{light_r:02X}"
                    }
                },
                "idiom": "universal"
            },
            {
                "appearances": [
                    {
                        "appearance": "luminosity",
                        "value": "dark"
                    }
                ],
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue": f"0x{dark_b:02X}",
                        "green": f"0x{dark_g:02X}",
                        "red": f"0x{dark_r:02X}"
                    }
                },
                "idiom": "universal"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

# Create color sets
base_path = "Assets/Colors.xcassets"

for color_family, color_variants in colors.items():
    for color_name, color_modes in color_variants.items():
        # Create directory
        color_dir = f"{base_path}/{color_name}.colorset"
        os.makedirs(color_dir, exist_ok=True)
        
        # Create JSON file with light and dark mode
        json_content = create_color_set_json(
            color_name, 
            color_modes["light"], 
            color_modes["dark"]
        )
        with open(f"{color_dir}/Contents.json", "w") as f:
            json.dump(json_content, f, indent=2)
        
        print(f"Created {color_dir}/Contents.json (light + dark mode)")

print("All color sets with dark mode support created successfully!") 