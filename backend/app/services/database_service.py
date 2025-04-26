from sqlalchemy.orm import Session
from sqlalchemy import select
from ..models.user import User
from typing import List, Optional
import logging
from logging import LoggerAdapter
from agents import function_tool
from ..config.database import SessionLocal

class DatabaseService:
    def __init__(self):
        self.logger = LoggerAdapter(logging.getLogger(__name__), {"agent_name": "DatabaseService"})
        self.logger.info("Initializing DatabaseService")

    def _format_user(self, user: User) -> str:
        """Format a user object into a string representation"""
        return f"Username: {user.username}, Email: {user.email}, Created at: {user.created_at}, Updated at: {user.updated_at}"

    def get_all_users(self, db: Session) -> List[User]:
        """Get all users from the database"""
        try:
            stmt = select(User)
            result = db.execute(stmt)
            users = result.scalars().all()
            self.logger.info(f"Retrieved {len(users)} users")
            return users
        except Exception as e:
            self.logger.error(f"Error retrieving users: {str(e)}")
            raise

    def get_user_by_username(self, db: Session, username: str) -> Optional[User]:
        """Get a user by username"""
        try:
            user = db.query(User).filter(User.username == username).first()
            if user:
                self.logger.info(f"Retrieved user: {username}")
                self.logger.info(f"User details: {self._format_user(user)}")
            else:
                self.logger.info(f"User not found: {username}")
            return user
        except Exception as e:
            self.logger.error(f"Error retrieving user {username}: {str(e)}")
            raise

    def get_user_by_email(self, db: Session, email: str) -> Optional[User]:
        """Get a user by email"""
        try:
            user = db.query(User).filter(User.email == email).first()
            if user:
                self.logger.info(f"Retrieved user with email: {email}")
                self.logger.info(f"User details: {self._format_user(user)}")
            else:
                self.logger.info(f"User with email not found: {email}")
            return user
        except Exception as e:
            self.logger.error(f"Error retrieving user with email {email}: {str(e)}")
            raise

# Initialize service
database_service = DatabaseService()

# Tool functions
@function_tool
async def get_all_users_tool() -> List[str]:
    """Get all users from the database.
    
    Usage: Use when user asks to see all users or list all users.
    Example: "Show me all users" or "List all users in the database".
    Response format: "Here are all users in the database: [list of users]"
    """
    db = SessionLocal()
    try:
        users = database_service.get_all_users(db)
        return [database_service._format_user(user) for user in users]
    finally:
        db.close()

@function_tool
async def get_user_by_username_tool(username: str) -> Optional[str]:
    """Get a user by their username.
    
    Args:
        username: The username to search for.
        
    Usage: Use when user asks about a specific user by username.
    Example: "Find user with username 'john'" or "Get information about user 'alice'".
    Response format: "User information for [username]: [user details]"
    """
    db = SessionLocal()
    try:
        user = database_service.get_user_by_username(db, username)
        return database_service._format_user(user) if user else None
    finally:
        db.close()

@function_tool
async def get_user_by_email_tool(email: str) -> Optional[str]:
    """Get a user by their email address.
    
    Args:
        email: The email address to search for.
        
    Usage: Use when user asks about a user by their email.
    Example: "Find user with email 'john@example.com'" or "Get user information for 'alice@example.com'".
    Response format: "User information for email [email]: [user details]"
    """
    db = SessionLocal()
    try:
        user = database_service.get_user_by_email(db, email)
        return database_service._format_user(user) if user else None
    finally:
        db.close()
