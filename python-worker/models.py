from pydantic import BaseModel, Field
from typing import Optional, List, Union

class ColorInfo(BaseModel):
    name: Optional[str] = Field(default=None, description="Human readable colour name (e.g. Butter Yellow)")
    hex: Optional[str] = Field(default=None, description="Hex code for the colour (e.g. #F7D2C4)")

class ApparelMetadata(BaseModel):
    garment_present: Optional[bool] = Field(default=None, description="True if a garment is present in the image")
    jewelry_present: Optional[bool] = Field(default=None, description="True if jewelry is present in the image")
    multiple_garments_present: Optional[bool] = Field(default=None, description="True if both top and bottom garments are present")
    garment_pieces: Optional[List[str]] = Field(default=None, description="List of visible garment pieces e.g. ['Top', 'Bottom']")

    category: Optional[str] = Field(default=None, description="Main clothing category (e.g. Dress, Top, Bottom, Outerwear, Shoes, Accessories, Saree)")
    subcategory: Optional[str] = Field(default=None, description="More specific category (e.g. Silk Saree, Cocktail Dress, Blouse, Jeans, Sneakers)")
    gemstone_type: Optional[Union[List[str], str]] = Field(default=None, description="Gemstone or material(s) (e.g. Diamond, Ruby or ['Diamond', 'Emerald'])")
    metal_type: Optional[Union[List[str], str]] = Field(default=None, description="Metal material(s) (e.g. Gold, Silver or ['Gold', 'Silver'])")
    neckline: Optional[str] = Field(default=None, description="Neckline style (e.g. V-Neck, Crew, Halter, Strapless)")
    sleeve_type: Optional[str] = Field(default=None, description="Sleeve style (e.g. Sleeveless, Short, Long, Cap)")
    pattern: Optional[Union[List[str], str]] = Field(default=None, description="Pattern or print/texture(s) (e.g. Solid, Floral or ['Floral', 'Embellished'])")
    fabric: Optional[str] = Field(default=None, description="Fabric material (e.g. Cotton, Silk, Denim, Leather)")
    style: Optional[Union[List[str], str]] = Field(default=None, description="Overall aesthetic style(s)")
    occasion: Optional[Union[List[str], str]] = Field(default=None, description="Suitable occasion(s)")
    season: Optional[str] = Field(default=None, description="Suitable season (e.g. Summer, Winter, Fall, Spring, All Seasons)")
    primary_color: Optional[ColorInfo] = Field(default=None, description="Dominant colour of the garment")
    secondary_color: Optional[ColorInfo] = Field(default=None, description="Distinct secondary colour, if any")
    confidence: float = Field(default=1.0, description="Confidence score between 0.0 and 1.0", ge=0.0, le=1.0)


