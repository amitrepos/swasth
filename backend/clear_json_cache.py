"""Clear cached AI insights that contain raw JSON so they get regenerated with proper formatting."""
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(__file__))

from database import SessionLocal
import models

def clear_json_cached_insights():
    """Delete all cached AI insights that contain JSON or are nutrition analysis results."""
    db = SessionLocal()
    try:
        # Find all AI insight logs that contain JSON or are nutrition analysis
        json_insights = db.query(models.AiInsightLog).filter(
            (models.AiInsightLog.response_text.like('%```%')) |  # Has markdown
            (models.AiInsightLog.response_text.like('{"foods%')) |  # Has JSON foods array
            (models.AiInsightLog.prompt_summary.like('%nutrition%')),  # Nutrition analysis
        ).all()
        
        print(f"Found {len(json_insights)} cached insights with JSON or nutrition data")
        
        # Delete them so they get regenerated
        for insight in json_insights:
            print(f"  Deleting insight ID {insight.id} for profile {insight.profile_id} (summary: {insight.prompt_summary})")
            db.delete(insight)
        
        db.commit()
        print(f"\n✅ Deleted {len(json_insights)} cached insights")
        print("They will be regenerated with proper formatting on next request")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    print("="*80)
    print("Clearing cached AI insights with raw JSON...")
    print("="*80)
    clear_json_cached_insights()
