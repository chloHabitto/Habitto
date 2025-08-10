#!/usr/bin/env python3
import json
import os

# Define all primitive colors
colors = {
    "Yellow": {
        "yellow50": "#FEF6E6",
        "yellow100": "#FCE2B0", 
        "yellow200": "#FAD58A",
        "yellow300": "#F8C154",
        "yellow400": "#F7B533",
        "yellow500": "#F5A300",
        "yellow600": "#DF9400",
        "yellow700": "#AE7400",
        "yellow800": "#875A00",
        "yellow900": "#674400"
    },
    "Green": {
        "green50": "#EBF9EE",
        "green100": "#C0EECC",
        "green200": "#A2E5B3", 
        "green300": "#77D990",
        "green400": "#5DD27A",
        "green500": "#34C759",
        "green600": "#2FB551",
        "green700": "#258D3F",
        "green800": "#1D6D31",
        "green900": "#165425"
    },
    "Red": {
        "red50": "#FCEBEE",
        "red100": "#F7C0C9",
        "red200": "#F3A2AF",
        "red300": "#EE778A", 
        "red400": "#EA5D74",
        "red500": "#E53451",
        "red600": "#D02F4A",
        "red700": "#A3253A",
        "red800": "#7E1D2D",
        "red900": "#601622"
    },
    "Navy": {
        "navy50": "#E8E9ED",
        "navy100": "#B9BCC8",
        "navy200": "#979CAD",
        "navy300": "#676E87",
        "navy400": "#495270", 
        "navy500": "#1C274C",
        "navy600": "#192345",
        "navy700": "#141C36",
        "navy800": "#0F152A",
        "navy900": "#0C1020"
    },
    "PastelBlue": {
        "pastelBlue50": "#F4F6FF",
        "pastelBlue100": "#EDF1FF",
        "pastelBlue300": "#B3C4FF",
        "pastelBlue400": "#A4B9FF",
        "pastelBlue500": "#8DA7FF",
        "pastelBlue600": "#8098E8",
        "pastelBlue700": "#6477B5",
        "pastelBlue800": "#4E5C8C",
        "pastelBlue900": "#3B466B"
    },
    "Grey": {
        "grey50": "#F9F9F9",
        "grey100": "#ECECEF",
        "grey200": "#E3E3E7",
        "grey300": "#D7D7DC",
        "grey400": "#CFCFD5",
        "grey500": "#C3C3CB",
        "grey600": "#B1B1B9",
        "grey700": "#8A8A90",
        "grey800": "#6B6B70",
        "grey900": "#525255",
        "greyBlack": "#191919",
        "greyWhite": "#FFFFFF"
    }
}

def hex_to_rgb(hex_color):
    """Convert hex color to RGB components"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return r, g, b

def create_color_set_json(color_name, hex_value):
    """Create JSON for a color set"""
    r, g, b = hex_to_rgb(hex_value)
    
    return {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {
                        "alpha": "1.000",
                        "blue": f"0x{b:02X}",
                        "green": f"0x{g:02X}",
                        "red": f"0x{r:02X}"
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
    for color_name, hex_value in color_variants.items():
        # Create directory
        color_dir = f"{base_path}/{color_name}.colorset"
        os.makedirs(color_dir, exist_ok=True)
        
        # Create JSON file
        json_content = create_color_set_json(color_name, hex_value)
        with open(f"{color_dir}/Contents.json", "w") as f:
            json.dump(json_content, f, indent=2)
        
        print(f"Created {color_dir}/Contents.json")

print("All color sets created successfully!") 