# Campus Sync Feature Enhancement TODO

Approved plan to add/enhance: media attachments (picker/upload), push notifications (Cloud Functions triggers), UI polish (badges/recommendations/edit-delete), best UI.

## Steps (Breakdown)

1. **[x] Update pubspec.yaml**: Add image_picker, firebase_storage deps → `flutter pub get` (✅ deps resolved)
2. **[ ] Enhance CreatePostView**: Image picker/camera/upload to Firebase Storage → replace URL field
3. **[ ] Setup Firebase Cloud Functions**: Init functions/, add FCM triggers for comment/help/resolve/chat → deploy
4. **[ ] Update NotificationService**: Topic subscribe, tap handlers for nav to post/chat
5. **[ ] UI Polish - ActivityView**: Add badges/profile stats display
6. **[ ] Add Edit/Delete UI**: In PostDetailView (owner only)
7. **[ ] Add Recommendations**: Similar posts carousel in Home/PostDetail (category/location match)
8. **[ ] Update main.dart/wrapper.dart**: Global NotificationService init with messengerKey
9. **[ ] Test**: Media upload, push notifications (events), UI across screens/devices
10. **[ ] Complete**: Run `flutter pub upgrade`, final polish

Progress will be updated after each step completion.

Current: Starting step 1.
