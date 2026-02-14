import Foundation

struct TermPack: Identifiable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let icon: String
    let terms: [String]

    var name: String { String(localized: String.LocalizationValue(nameKey)) }
    var description: String { String(localized: String.LocalizationValue(descriptionKey)) }

    static let allPacks: [TermPack] = [
        TermPack(
            id: "web-dev",
            nameKey: "Web Development",
            descriptionKey: "termpack.webdev.description",
            icon: "globe",
            terms: [
                "React", "Vue", "Angular", "Next.js", "Nuxt", "Svelte",
                "TypeScript", "JavaScript", "Node.js", "Express",
                "Laravel", "Django", "FastAPI", "Ruby on Rails",
                "PostgreSQL", "MongoDB", "Redis", "GraphQL",
                "Tailwind", "Webpack", "Vite", "npm", "Yarn",
                "REST API", "WebSocket", "OAuth", "JWT",
                "Vercel", "Netlify", "Prisma", "Supabase"
            ]
        ),
        TermPack(
            id: "ios-macos",
            nameKey: "iOS / macOS",
            descriptionKey: "termpack.ios.description",
            icon: "apple.logo",
            terms: [
                "Xcode", "SwiftUI", "UIKit", "AppKit",
                "CocoaPods", "Swift Package Manager", "Carthage",
                "TestFlight", "CloudKit", "Core Data", "SwiftData",
                "Combine", "async await", "Actor",
                "StoreKit", "WidgetKit", "App Intents",
                "Metal", "Core ML", "ARKit", "RealityKit",
                "Instruments", "LLDB", "Simulator",
                "Info.plist", "Entitlements", "Provisioning Profile",
                "App Store Connect", "Xcode Cloud"
            ]
        ),
        TermPack(
            id: "devops",
            nameKey: "DevOps & Cloud",
            descriptionKey: "termpack.devops.description",
            icon: "cloud",
            terms: [
                "Kubernetes", "Docker", "Terraform", "Ansible",
                "AWS", "Azure", "Google Cloud", "Cloudflare",
                "GitHub Actions", "GitLab CI", "Jenkins", "CircleCI",
                "Nginx", "Apache", "Caddy",
                "Prometheus", "Grafana", "Datadog",
                "Helm", "Istio", "ArgoCD",
                "S3", "EC2", "Lambda", "ECS", "EKS",
                "VPC", "CDN", "DNS", "SSL", "TLS"
            ]
        ),
        TermPack(
            id: "data-ai",
            nameKey: "Data & AI",
            descriptionKey: "termpack.ai.description",
            icon: "brain",
            terms: [
                "TensorFlow", "PyTorch", "Keras",
                "Jupyter", "pandas", "NumPy", "scikit-learn",
                "Hugging Face", "LangChain", "OpenAI",
                "GPT", "Claude", "LLM", "RAG",
                "CUDA", "MLOps", "MLflow",
                "Transformer", "BERT", "LoRA",
                "Embeddings", "Vector Database", "Pinecone",
                "Fine-tuning", "Prompt Engineering",
                "Matplotlib", "Seaborn", "Plotly"
            ]
        ),
        TermPack(
            id: "design",
            nameKey: "Design",
            descriptionKey: "termpack.design.description",
            icon: "paintbrush",
            terms: [
                "Figma", "Sketch", "Zeplin", "InVision",
                "Adobe XD", "Photoshop", "Illustrator",
                "Auto Layout", "Responsive Design",
                "Wireframe", "Mockup", "Prototype",
                "Design System", "Style Guide",
                "Typography", "Kerning", "Leading",
                "Bezier", "Vector", "Rasterize",
                "WCAG", "Accessibility", "Color Contrast",
                "Lottie", "Rive"
            ]
        )
    ]
}
