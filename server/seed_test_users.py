from datetime import datetime

from app import create_app
from app.extensions import db, bcrypt
from app.models import User


def get_or_create_user(email, role, password_plain, verified=True, enrolled=True):
    user = User.query.filter_by(email=email).first()
    hashed = bcrypt.generate_password_hash(password_plain).decode("utf-8")

    if user:
        print(f"🔄 Updated existing user: {email} ({role})")
        user.role = role
        user.password = hashed
        user.is_verified = verified
        user.enrollment_completed = enrolled
        user.is_active = True
        if not user.created_at:
            user.created_at = datetime.utcnow()
    else:
        print(f"➕ Created new user: {email} ({role})")
        user = User(
            email=email,
            password=hashed,
            role=role,
            is_verified=verified,
            enrollment_completed=enrolled,
            is_active=True,
            created_at=datetime.utcnow(),
        )
        db.session.add(user)

    return user


def main():
    app = create_app()

    with app.app_context():
        print("📝 Creating test users...")
        print("=" * 60)

        # Admin users
        get_or_create_user(
            email="admin@khonorecruit.com",
            role="admin",
            password_plain="admin123",
            verified=True,
            enrolled=True,
        )

        get_or_create_user(
            email="jane.admin@khonorecruit.com",
            role="admin",
            password_plain="janeadmin456",
            verified=True,
            enrolled=True,
        )

        # Hiring managers
        get_or_create_user(
            email="john.manager@khonorecruit.com",
            role="hiring_manager",
            password_plain="johnmanager789",
            verified=True,
            enrolled=True,
        )

        get_or_create_user(
            email="sarah.hr@khonorecruit.com",
            role="hiring_manager",
            password_plain="sarahhr321",
            verified=True,
            enrolled=True,
        )

        db.session.commit()

        print("\n✅ All users created/updated successfully!\n")

        print("📋 Test Users Summary:")
        print("=" * 60)
        for email in [
            "admin@khonorecruit.com",
            "jane.admin@khonorecruit.com",
            "john.manager@khonorecruit.com",
            "sarah.hr@khonorecruit.com",
        ]:
            user = User.query.filter_by(email=email).first()
            if user:
                print(
                    f"✅ {user.email} | {user.role} | "
                    f"Verified: {user.is_verified} | Enrolled: {user.enrollment_completed}"
                )

        print("\n🔐 Login Credentials:")
        print("=" * 60)
        print("ADMIN USERS:")
        print("├── Email: admin@khonorecruit.com")
        print("│   Password: admin123")
        print("├── Email: jane.admin@khonorecruit.com")
        print("│   Password: janeadmin456\n")
        print("HIRING MANAGERS:")
        print("├── Email: john.manager@khonorecruit.com")
        print("│   Password: johnmanager789")
        print("└── Email: sarah.hr@khonorecruit.com")
        print("    Password: sarahhr321")


if __name__ == "__main__":
    main()