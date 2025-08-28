# Architecture Documentation

This directory contains comprehensive technical documentation for the Mostro Mobile application architecture. These documents serve as reference for understanding the system's design, implementation patterns, and core functionality.


## 🔄 Documentation Update Process

### 1. **Before Making Code Changes**
- Review relevant documentation to understand current architecture
- Identify which documents will be affected by your changes
- Note specific sections that will need updates

### 2. **During Development**
- Keep track of architectural decisions and new patterns introduced
- Document any deviations from existing patterns
- Note new dependencies or configuration changes

### 3. **After Code Changes**
- **Immediately update affected documentation**
- Verify code examples still match actual implementation
- Update line numbers if referencing specific code locations
- Test that all references and links still work

### 4. **Documentation Quality Checklist**
- [ ] Code examples match actual implementation
- [ ] Line numbers are accurate (if referenced)
- [ ] New components/patterns are documented
- [ ] External links are functional
- [ ] Cross-references between documents are correct
- [ ] Technical accuracy verified against codebase

---

## 📝 Documentation Standards

### **Writing Guidelines**
- **Technical Accuracy**: All code examples must match actual implementation
- **Educational Value**: Explain *why* decisions were made, not just *what*
- **Comprehensive Coverage**: Document both happy path and edge cases
- **Code References**: Include file paths and line numbers where helpful
- **Version Tracking**: Update "Last Updated" dates when making changes

### **Code Example Standards**
- Use actual code from the codebase, not pseudo-code
- Include file paths: `lib/features/order/notfiers/order_notifier.dart`
- Add line numbers for specific references: `// Line 45-67`
- Show complete context, not just isolated snippets
- Validate examples still compile and work

### **Architecture Diagram Guidelines**
- Use ASCII art for simple diagrams (better for version control)
- Keep diagrams up-to-date with actual implementation
- Show data flow and component relationships clearly
- Include both logical and physical architecture views

---


### **Generated Files**
⚠️ **Never update documentation based on generated files** (`.g.dart`, `.mocks.dart`)
- Generated files change automatically
- Focus on source files that generate them
- Document the generation process, not generated content


**Remember**: Documentation is code infrastructure. Treat it with the same care and attention as the application code itself. Well-maintained documentation accelerates development, reduces bugs, and enables confident architectural changes.
