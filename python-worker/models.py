from pydantic import BaseModel, Field
from typing import Optional

class ColorInfo(BaseModel):
    name: Optional[str] = Field(default=None, description="Human readable colour name (e.g. Butter Yellow)")
    hex: Optional[str] = Field(default=None, description="Hex code for the colour (e.g. #F7D2C4)")

class ApparelMetadata(BaseModel):
    category: Optional[str] = Field(description="Main clothing category (e.g. Dress, Top, Bottom, Outerwear, Shoes, Accessories)")
    subcategory: Optional[str] = Field(description="More specific category (e.g. Cocktail Dress, Blouse, Jeans, Sneakers)")
    neckline: Optional[str] = Field(description="Neckline style (e.g. V-Neck, Crew, Halter, Strapless)")
    sleeve_type: Optional[str] = Field(description="Sleeve style (e.g. Sleeveless, Short, Long, Cap)")
    pattern: Optional[str] = Field(description="Pattern or print (e.g. Solid, Floral, Striped, Plaid)")
    fabric: Optional[str] = Field(description="Fabric material (e.g. Cotton, Silk, Denim, Leather)")
    style: Optional[str] = Field(description="Overall aesthetic style (e.g. Casual, Formal, Bohemian, Minimalist)")
    occasion: Optional[str] = Field(description="Suitable occasion (e.g. Everyday, Evening, Work, Activewear)")
    season: Optional[str] = Field(description="Suitable season (e.g. Summer, Winter, Fall, Spring, All Seasons)")
    # Without these the model's colours are silently dropped during validation
    # and the item ends up with no colour at all.
    primary_color: Optional[ColorInfo] = Field(default=None, description="Dominant colour of the garment")
    secondary_color: Optional[ColorInfo] = Field(default=None, description="Distinct secondary colour, if any")
    confidence: float = Field(description="Confidence score between 0.0 and 1.0", ge=0.0, le=1.0)
