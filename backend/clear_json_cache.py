"""Utility to clear JSON cached AI insights from the database."""
import logging
from sqlalchemy import or_
from database import SessionLocal
from models import AiInsightLog

logger = logging.getLogger(__name__)


def clear_json_cached_insights():
    """
    Clear AI insight logs that contain JSON cached data.
    
    This function removes insights that:
    - Contain markdown code blocks (```)
    - Contain JSON foods arrays
    - Have 'nutrition' in their prompt_summary
    
    These are typically old cached insights that need to be refreshed.
    """
    db = SessionLocal()
    try:
        # Query for insights matching any of the criteria
        insights = (
            db.query(AiInsightLog)
            .filter(
                or_(
                    AiInsightLog.response_text.like("%```%"),
                    AiInsightLog.response_text.like('%"foods"%'),
                    AiInsightLog.prompt_summary.like("%nutrition%")
                )
            )
            .all()
        )
        
        logger.info(f"Found {len(insights)} cached insights to clear")
        print(f"Found {len(insights)} cached insights")
        
        # Delete all matching insights
        for insight in insights:
            db.delete(insight)
        
        db.commit()
        logger.info(f"Deleted {len(insights)} cached insights")
        print(f"Deleted {len(insights)} cached insights")
        
    except Exception as e:
        db.rollback()
        logger.error(f"Error clearing cached insights: {str(e)}")
        print(f"Error: {str(e)}")
    finally:
        db.close()


if __name__ == "__main__":
    clear_json_cached_insights()
