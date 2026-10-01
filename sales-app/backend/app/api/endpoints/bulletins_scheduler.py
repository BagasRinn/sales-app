"""Scheduler helper functions for bulletin auto-expire and monthly reset."""
from sqlalchemy.orm import Session
from app.models.database import engine
from datetime import datetime, timezone, timedelta


def expire_bulletins():
    """Delete expired bulletins, dismiss records, and their PDF files. Run daily at 00:05 WITA."""
    db = Session(bind=engine)
    try:
        from app.models.models import Bulletin, BulletinDismiss
        from app.services.supabase_storage import delete_file

        wita = timezone(timedelta(hours=8))
        now_wita = datetime.now(wita)

        expired = db.query(Bulletin).filter(
            Bulletin.expire_at.isnot(None),
            Bulletin.expire_at < now_wita,
        ).all()

        if not expired:
            return

        for b in expired:
            if b.pdf_url:
                try:
                    delete_file(b.pdf_url)
                except Exception:
                    pass

        ids = [b.id for b in expired]
        db.query(BulletinDismiss).filter(BulletinDismiss.bulletin_id.in_(ids)).delete(synchronize_session=False)
        db.query(Bulletin).filter(Bulletin.id.in_(ids)).delete(synchronize_session=False)
        db.commit()
        print(f"[BULLETIN SCHEDULER] Deleted {len(expired)} expired bulletins.")
    except Exception as e:
        db.rollback()
        print(f"[BULLETIN SCHEDULER] Error expiring bulletins: {e}")
    finally:
        db.close()


def reset_all_bulletins():
    """Delete ALL bulletins, dismiss records, and PDF files. Run on day 1 of every month at 00:10 WITA."""
    db = Session(bind=engine)
    try:
        from app.models.models import Bulletin, BulletinDismiss
        from app.services.supabase_storage import delete_file

        bulletins = db.query(Bulletin).all()
        for b in bulletins:
            if b.pdf_url:
                try:
                    delete_file(b.pdf_url)
                except Exception:
                    pass

        db.query(BulletinDismiss).delete(synchronize_session=False)
        db.query(Bulletin).delete(synchronize_session=False)
        db.commit()
        print("[BULLETIN SCHEDULER] Monthly reset: all bulletins and PDFs deleted.")
    except Exception as e:
        db.rollback()
        print(f"[BULLETIN SCHEDULER] Error resetting bulletins: {e}")
    finally:
        db.close()
