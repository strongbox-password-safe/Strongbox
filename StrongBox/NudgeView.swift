import UIKit

@objcMembers
class NudgeView: UIControl {
    private let iconImageView = UIImageView(image: UIImage(systemName: "star.circle.fill"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.forward"))
    private let contentStack = UIStackView()
    private let textStack = UIStackView()

    var titleText: String? {
        didSet {
            titleLabel.text = titleText
            updateAccessibilityLabel()
        }
    }

    var subtitleText: String? {
        didSet {
            subtitleLabel.text = subtitleText
            subtitleLabel.isHidden = subtitleText?.isEmpty ?? true
            updateAccessibilityLabel()
        }
    }

    
    var useUrgentStyle: Bool = false {
        didSet {
            updateColorScheme()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        updateColorScheme()

        tintColor = .white
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        layer.masksToBounds = true

        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        chevronImageView.tintColor = UIColor.white.withAlphaComponent(0.85)
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        chevronImageView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        subtitleLabel.numberOfLines = 2
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.isHidden = true

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.fittingSizeLevel, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)

        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(textStack)
        contentStack.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(chevronImageView)

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])

        contentStack.isUserInteractionEnabled = false

        isAccessibilityElement = true
        accessibilityTraits.insert(.button)
        accessibilityIdentifier = "nudge-view"
    }

    private func updateColorScheme() {
        let baseColor: UIColor = useUrgentStyle ? .systemOrange : .systemBlue
        backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? baseColor.withAlphaComponent(0.92) : baseColor
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.alpha = self.isHighlighted ? 0.6 : 1.0
            }
        }
    }

    private func updateAccessibilityLabel() {
        let parts = [titleText, subtitleText?.isEmpty == false ? subtitleText : nil].compactMap { $0 }
        accessibilityLabel = parts.joined(separator: ". ")
    }
}
