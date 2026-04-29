"""Utility to clear JSON cached AI insights from the database."""
import logging
from sqlalchemy import or_
from database import SessionLocal
from models import AiInsightLog

logger = logging.getLogger(__name__)

# Safety limit to prevent accidental bulk deletes
MAX_ROWS_PER_RUN = 1000


def clear_json_cached_insights(dry_run: bool = True, limit: int = MAX_ROWS_PER_RUN):
    """
    Clear AI insight logs that contain JSON cached data.
    
    This function removes insights that:
    - Contain markdown code blocks (```)
    - Contain JSON foods arrays
    - Have 'nutrition' in their prompt_summary
    
    These are typically old cached insights that need to be refreshed.
    
    Args:
        dry_run: If True, only counts matching rows without deleting
        limit: Maximum number of rows to delete (safety cap)
    """
    db = SessionLocal()
    try:
        # Query for insights matching any of the criteria
        insights_query = (
            db.query(AiInsightLog)
            .filter(
                or_(
                    AiInsightLog.response_text.like("%```%"),
                    AiInsightLog.response_text.like('%"foods"%'),
                    AiInsightLog.prompt_summary.like("%nutrition%")
                )
            )
        )
        
        # Count total matching rows
        total_count = insights_query.count()
        logger.info(f"Found {total_count} cached insights matching criteria")
        
        if total_count == 0:
            logger.info("No cached insights to clear")
            return 0
        
        # Apply limit for safety
        insights = insights_query.limit(limit).all()
        limited_count = len(insights)
        
        if limited_count < total_count:
            logger.warning(
                f"Limited to {limited_count} rows (out of {total_count} total) "
                f"for safety. Run multiple times or increase limit if needed."
            )
        
        if dry_run:
            logger.info(f"[DRY RUN] Would delete {limited_count} cached insights")
            return limited_count
        
        logger.info(f"Proceeding to delete {limited_count} cached insights")
        
        # Delete all matching insights
        for insight in insights:
            db.delete(insight)
        
        db.commit()
        logger.info(f"Successfully deleted {limited_count} cached insights")
        return limited_count
        
    except Exception as e:
        db.rollback()
        logger.error(f"Error clearing cached insights: {str(e)}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    import sys
    
    # Parse command-line arguments
    dry_run = "--execute" not in sys.argv
    limit = MAX_ROWS_PER_RUN
    
    # Check for custom limit
    for arg in sys.argv:
        if arg.startswith("--limit="):
            try:
                limit = int(arg.split("=", 1)[1])
            except ValueError:
                logger.error(f"Invalid limit value: {arg}")
                sys.exit(1)
    
    if dry_run:
        logger.info("=" * 60)
        logger.info("DRY RUN MODE - No rows will be deleted")
        logger.info("Use --execute flag to perform actual deletion")
        logger.info("=" * 60)
    else:
        logger.info("=" * 60)
        logger.info("EXECUTION MODE - Rows WILL be deleted")
        logger.info("=" * 60)
        
        # Require explicit confirmation for execution
        confirm = input(f"\nDelete up to {limit} rows? (yes/no): ")
        if confirm.lower() != "yes":
            logger.info("Operation cancelled by user")
            sys.exit(0)
    
    try:
        deleted_count = clear_json_cached_insights(dry_run=dry_run, limit=limit)
        logger.info(f"Operation complete. Affected rows: {deleted_count}")
    except Exception as e:
        logger.error(f"Operation failed: {e}")
        sys.exit(1)
